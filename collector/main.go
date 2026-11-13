package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/jackc/pgx/v5/pgxpool"
)

const schema = `
CREATE TABLE IF NOT EXISTS readings (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    node_name text NOT NULL,
    recorded_at timestamptz NOT NULL,
    temperature double precision NOT NULL,
    pressure double precision NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS readings_node_time_idx
    ON readings (node_name, recorded_at DESC);`

type payload struct {
	Time        string   `json:"time"`
	Temperature *float64 `json:"temperature"`
	Pressure    *float64 `json:"pressure"`
}

type reading struct {
	Node        string
	RecordedAt  time.Time
	Temperature float64
	Pressure    float64
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	mqttPassword, err := readSecret(env("MQTT_PASSWORD_FILE", "/run/secrets/collector_password"))
	if err != nil {
		logger.Error("read MQTT password", "error", err)
		os.Exit(1)
	}
	dbPassword, err := readSecret(env("POSTGRES_PASSWORD_FILE", "/run/secrets/postgres_password"))
	if err != nil {
		logger.Error("read PostgreSQL password", "error", err)
		os.Exit(1)
	}

	dbURL := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(env("POSTGRES_USER", "meteo"), dbPassword),
		Host:   env("POSTGRES_HOST", "postgres") + ":" + env("POSTGRES_PORT", "5432"),
		Path:   env("POSTGRES_DB", "meteo"),
	}
	query := dbURL.Query()
	query.Set("sslmode", "disable")
	dbURL.RawQuery = query.Encode()

	pool, err := pgxpool.New(ctx, dbURL.String())
	if err != nil {
		logger.Error("configure PostgreSQL", "error", err)
		os.Exit(1)
	}
	defer pool.Close()
	if err := waitForDatabase(ctx, pool); err != nil {
		logger.Error("connect to PostgreSQL", "error", err)
		os.Exit(1)
	}
	if _, err := pool.Exec(ctx, schema); err != nil {
		logger.Error("initialize database schema", "error", err)
		os.Exit(1)
	}

	handler := func(_ mqtt.Client, message mqtt.Message) {
		r, err := parseReading(message.Topic(), message.Payload(), time.Now().UTC())
		if err != nil {
			logger.Warn("discard invalid MQTT reading", "topic", message.Topic(), "error", err)
			return
		}
		insertCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		_, err = pool.Exec(insertCtx, `
            INSERT INTO readings (node_name, recorded_at, temperature, pressure)
            VALUES ($1, $2, $3, $4)`,
			r.Node, r.RecordedAt, r.Temperature, r.Pressure)
		if err != nil {
			logger.Error("store MQTT reading", "node", r.Node, "error", err)
			return
		}
		logger.Info("stored MQTT reading", "node", r.Node, "recorded_at", r.RecordedAt)
	}

	options := mqtt.NewClientOptions().
		AddBroker(env("MQTT_BROKER", "tcp://mosquitto:1883")).
		SetClientID("pocket-meteo-sql-collector").
		SetUsername(env("MQTT_USERNAME", "collector")).
		SetPassword(mqttPassword).
		SetAutoReconnect(true).
		SetConnectRetry(true).
		SetConnectRetryInterval(3 * time.Second).
		SetOrderMatters(false).
		SetOnConnectHandler(func(client mqtt.Client) {
			if token := client.Subscribe("pocketmeteo/+/data", 1, handler); token.Wait() && token.Error() != nil {
				logger.Error("subscribe to MQTT", "error", token.Error())
				return
			}
			logger.Info("subscribed to MQTT readings")
		}).
		SetConnectionLostHandler(func(_ mqtt.Client, err error) {
			logger.Warn("MQTT connection lost", "error", err)
		})

	client := mqtt.NewClient(options)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		logger.Error("connect to MQTT", "error", token.Error())
		os.Exit(1)
	}
	logger.Info("collector started")
	<-ctx.Done()
	client.Disconnect(1000)
	logger.Info("collector stopped")
}

func parseReading(topic string, data []byte, receivedAt time.Time) (reading, error) {
	parts := strings.Split(topic, "/")
	if len(parts) != 3 || parts[0] != "pocketmeteo" || parts[1] == "" || parts[2] != "data" {
		return reading{}, fmt.Errorf("unexpected topic %q", topic)
	}

	var p payload
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&p); err != nil {
		return reading{}, fmt.Errorf("decode JSON: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return reading{}, fmt.Errorf("payload must contain exactly one JSON object")
	}
	if p.Temperature == nil || p.Pressure == nil {
		return reading{}, fmt.Errorf("temperature and pressure are required")
	}

	recordedAt := receivedAt
	if p.Time != "" {
		parsed, err := time.Parse(time.RFC3339Nano, p.Time)
		if err != nil {
			return reading{}, fmt.Errorf("invalid time: %w", err)
		}
		recordedAt = parsed
	}
	return reading{
		Node:        parts[1],
		RecordedAt:  recordedAt,
		Temperature: *p.Temperature,
		Pressure:    *p.Pressure,
	}, nil
}

func readSecret(path string) (string, error) {
	value, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	secret := strings.TrimSpace(string(value))
	if secret == "" {
		return "", fmt.Errorf("secret file %s is empty", path)
	}
	return secret, nil
}

func env(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func waitForDatabase(ctx context.Context, pool *pgxpool.Pool) error {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		err := pool.Ping(pingCtx)
		cancel()
		if err == nil {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}
