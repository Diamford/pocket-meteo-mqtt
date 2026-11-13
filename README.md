# Pocket Meteo MQTT for Ubuntu VPS

This is a standalone Mosquitto server for an Ubuntu VPS. Mosquitto runs through
Docker Compose, keeps its broker database in a named Docker volume, and does not
allow anonymous access.

## First start

Install Docker Engine with the Compose plugin on the VPS, copy this repository
there, and create one password file for every MQTT user. Each file must contain
only the password (a trailing newline is allowed):

```console
mkdir -p secrets
chmod 700 secrets
printf '%s' 'CHANGE_ME' > secrets/collector
printf '%s' 'CHANGE_ME_CHAT_1' > secrets/chat01
printf '%s' 'CHANGE_ME_CHAT_2' > secrets/chat02
printf '%s' 'CHANGE_ME_DATABASE' > secrets/postgres
chmod 600 secrets/*
docker compose up -d
```

The files under `secrets/` are ignored by Git. To keep them elsewhere, set
`MQTT_SECRETS_DIR` to an absolute directory when running Compose.

## Add a node

Add a node with one command from the repository directory:

```console
./add-node my-station
```

There are no nodes by default. Choose any unique name made of lowercase ASCII
letters, digits, hyphens, and underscores. The name must start and end with a
letter or digit; `collector`, `chat01`, and `chat02` are reserved.

The command generates a 256-bit password with Python's cryptographic `secrets`
module, stores it in the corresponding file such as `secrets/my-station` with
mode `600`, adds the node to `docker/nodes`, and recreates the authentication
helper and broker containers. It prints the password once so it can be copied
to the device. The new node may publish only to its corresponding topic, such
as `pocketmeteo/my-station/data`.

Use `./add-node --no-restart my-station` to only update the files, for example
while preparing the server before its first start. If secrets are kept
elsewhere, pass the same setting used by Compose:

```console
MQTT_SECRETS_DIR=/absolute/private/path ./add-node my-station
```

## Access rules

- Nodes listed in `docker/nodes` may publish only to their corresponding
  `pocketmeteo/NODE_NAME/data` topic.
- `collector` may subscribe to `pocketmeteo/+/data` and cannot publish.
- `chat01` and `chat02` may both publish and subscribe to
  `pocketmeteo/chat/messages`. They are intended for the two-phone chat test.

## SQL storage

The Go collector subscribes to every node data topic and stores readings in
PostgreSQL 18. Nodes publish JSON to `pocketmeteo/NODE_NAME/data`:

```json
{"time":"2026-11-13T12:00:00Z","temperature":21.5,"pressure":1013.2}
```

`time` must be RFC 3339 and may be omitted; in that case the collector uses its
receive time. The node name is taken from the authenticated node's topic, not
from the payload. PostgreSQL is available only inside the Compose network.

View the latest readings:

```console
docker compose exec postgres psql -U meteo -d meteo -c \
  'SELECT node_name, recorded_at, temperature, pressure FROM readings ORDER BY recorded_at DESC LIMIT 20;'
```

The database is kept in the `postgres-data` volume. Collector events and
invalid payloads are visible with `docker compose logs collector`.

## Two-phone chat test

The Compose stack also serves a small browser chat on port `8080`; browser MQTT
connections use WebSockets on port `9001`.

1. Start the stack with `docker compose up -d` and allow TCP ports `8080` and
   `9001` in the VPS firewall.
2. Open `http://YOUR_SERVER_IP:8080` on both phones. Both phones must be able to
   reach the server; do not use `localhost` in a phone browser.
3. On phone 1 enter user `chat01` and its password. On phone 2 enter `chat02`
   and its password. The server field is filled from the page address.
4. Press **Connect** on both phones and send messages in either direction.

Messages are not retained after every client has received them, so this is a
live connectivity test rather than durable chat history. The page itself loads
MQTT.js from jsDelivr; each phone therefore needs Internet access in addition
to access to the VPS.

After changing a password, run `docker compose up -d --force-recreate
mosquitto-init mosquitto`. Broker messages survive container recreation in the
`mosquitto-data` volume.

Useful commands:

```console
docker compose ps
# Show recent broker events.
docker compose logs --tail=100 mosquitto
# Follow broker events in real time.
docker compose logs -f mosquitto
docker compose down
```

The broker logs connections, authentication failures, subscriptions and other
service events to the container log. Docker keeps up to five 10 MB log files,
so logs cannot grow without a limit. MQTT payloads and passwords are not
written to the log.

If UFW is enabled on the VPS, allow incoming MQTT connections:

```console
sudo ufw allow 1883/tcp
sudo ufw allow 9001/tcp
sudo ufw allow 8080/tcp
```

Ports `1883` and `9001` carry unencrypted MQTT traffic (including login
credentials). If clients connect over the public Internet, put the broker behind
a private VPN or add TLS/secure WebSockets before using it in production.
