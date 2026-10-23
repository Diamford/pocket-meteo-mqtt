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
printf '%s' 'CHANGE_ME' > secrets/station01
printf '%s' 'CHANGE_ME' > secrets/station02
printf '%s' 'CHANGE_ME' > secrets/station03
printf '%s' 'CHANGE_ME' > secrets/station04
printf '%s' 'CHANGE_ME' > secrets/station05
printf '%s' 'CHANGE_ME' > secrets/collector
chmod 600 secrets/*
docker compose up -d
```

The files under `secrets/` are ignored by Git. To keep them elsewhere, set
`MQTT_SECRETS_DIR` to an absolute directory when running Compose.

## Access rules

- `station01` ... `station05` may publish only to their corresponding
  `pocketmeteo/stationXX/data` topic.
- `collector` may subscribe to `pocketmeteo/+/data` and cannot publish.

After changing a password, run `docker compose up -d --force-recreate
mosquitto-init mosquitto`. Broker messages survive container recreation in the
`mosquitto-data` volume.

Useful commands:

```console
docker compose ps
docker compose logs -f mosquitto
docker compose down
```

If UFW is enabled on the VPS, allow incoming MQTT connections:

```console
sudo ufw allow 1883/tcp
```

Port `1883` carries unencrypted MQTT traffic. If clients connect over the public
Internet, put the broker behind a private VPN or add a TLS listener before using
it in production.
