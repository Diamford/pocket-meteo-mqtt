#!/bin/sh
set -eu

password_file=/generated/passwords.tmp
final_password_file=/generated/passwords
acl_file=/generated/acl.tmp
final_acl_file=/generated/acl

umask 077
: > "$password_file"
: > "$acl_file"

add_user() {
  username=$1
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
}

for username in $MQTT_BASE_USERS; do
  add_user "$username"
done

cat >> "$acl_file" <<'EOF'
user collector
topic read pocketmeteo/+/data

user chat01
topic readwrite pocketmeteo/chat/messages

user chat02
topic readwrite pocketmeteo/chat/messages
EOF

while IFS= read -r username || [ -n "$username" ]; do
  case "$username" in
    ''|'#'*) continue ;;
    collector|chat01|chat02)
      echo "Reserved MQTT username in /config/nodes: $username" >&2
      exit 1
      ;;
    *[!a-z0-9_-]*|-*|_*|*[!a-z0-9])
      echo "Invalid MQTT node name in /config/nodes: $username" >&2
      exit 1
      ;;
  esac

  add_user "$username"
  cat >> "$acl_file" <<EOF

user $username
topic write pocketmeteo/$username/data
EOF
done < /config/nodes

# Convert the temporary user:password file to Mosquitto's hashed format.
mosquitto_passwd -U "$password_file"
chmod 0644 "$password_file"
chmod 0644 "$acl_file"
mv "$password_file" "$final_password_file"
mv "$acl_file" "$final_acl_file"
