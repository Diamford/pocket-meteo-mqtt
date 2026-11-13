package main

import (
	"testing"
	"time"
)

func TestParseReading(t *testing.T) {
	now := time.Date(2026, 11, 13, 12, 0, 0, 0, time.UTC)
	r, err := parseReading("pocketmeteo/field-unit/data", []byte(`{"time":"2026-11-13T11:59:30Z","temperature":21.5,"pressure":1013.2}`), now)
	if err != nil {
		t.Fatal(err)
	}
	if r.Node != "field-unit" || r.Temperature != 21.5 || r.Pressure != 1013.2 {
		t.Fatalf("unexpected reading: %+v", r)
	}
	if want := "2026-11-13T11:59:30Z"; r.RecordedAt.Format(time.RFC3339) != want {
		t.Fatalf("recorded time = %s, want %s", r.RecordedAt, want)
	}
}

func TestParseReadingUsesReceiveTime(t *testing.T) {
	now := time.Date(2026, 11, 13, 12, 0, 0, 0, time.UTC)
	r, err := parseReading("pocketmeteo/node_1/data", []byte(`{"temperature":-4.25,"pressure":998}`), now)
	if err != nil {
		t.Fatal(err)
	}
	if !r.RecordedAt.Equal(now) {
		t.Fatalf("recorded time = %s, want %s", r.RecordedAt, now)
	}
}

func TestParseReadingRejectsInvalidInput(t *testing.T) {
	tests := []struct {
		name    string
		topic   string
		payload string
	}{
		{"topic", "pocketmeteo/node/status", `{"temperature":1,"pressure":2}`},
		{"json", "pocketmeteo/node/data", `{`},
		{"time", "pocketmeteo/node/data", `{"time":"yesterday","temperature":1,"pressure":2}`},
		{"unknown field", "pocketmeteo/node/data", `{"temperature":1,"pressure":2,"humidity":3}`},
		{"missing temperature", "pocketmeteo/node/data", `{"pressure":2}`},
		{"multiple objects", "pocketmeteo/node/data", `{"temperature":1,"pressure":2} {"temperature":3,"pressure":4}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := parseReading(tt.topic, []byte(tt.payload), time.Now()); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
}
