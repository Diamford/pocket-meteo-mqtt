#!/bin/sh
set -eu

password_file=/generated/passwords.tmp
final_password_file=/generated/passwords

umask 077
: > "$password_file"

for username in $MQTT_USERS; do
  secret_file="/run/secrets/$username"

  if [ ! -s "$secret_file" ]; then
    echo "Missing or empty MQTT password file: $secret_file" >&2
    exit 1
  fi

  password=$(cat "$secret_file")
  case "$password" in
    *:*)
      echo "Password for $username must not contain a colon" >&2
      exit 1
      ;;
  esac

  printf '%s:%s\n' "$username" "$password" >> "$password_file"
done

# Convert the temporary user:password file to Mosquitto's hashed format.
mosquitto_passwd -U "$password_file"
chmod 0644 "$password_file"
mv "$password_file" "$final_password_file"
