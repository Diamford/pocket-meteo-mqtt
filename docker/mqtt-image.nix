{ pkgs, lib, nixpkgs, system }:

let
  nixos = nixpkgs.lib.nixosSystem {
    inherit system;

    modules = [
      ../mqtt.nix
      {
        system.stateVersion = "25.11";
        boot.isContainer = true;
      }
    ];
  };

  mqtt = nixos.config.services.mosquitto;
  listener = builtins.head mqtt.listeners;
  users = listener.users;
  names = builtins.attrNames users;

  acl = pkgs.writeText "pocketmeteo.acl" (
    lib.concatMapStringsSep "\n" (name:
      "user ${name}\n" +
      lib.concatMapStringsSep "\n"
        (rule: "topic ${rule}")
        users.${name}.acl
    ) names
  );

  setup = lib.concatMapStringsSep "\n" (name: ''
    file=${lib.escapeShellArg (toString users.${name}.passwordFile)}
    if [ ! -s "$file" ]; then
      echo "Missing password: $file" >&2
      exit 1
    fi

    password="$(cat "$file")"
    ${pkgs.mosquitto}/bin/mosquitto_passwd \
      -b "$passwd" ${lib.escapeShellArg name} "$password"
    unset password
  '') names;

  entrypoint = pkgs.writeShellScriptBin "start-mqtt" ''
    set -eu
    umask 077

    mkdir -p /mosquitto/data /tmp/mqtt-runtime
    passwd=/tmp/mqtt-runtime/passwd
    : > "$passwd"

    ${setup}

    cat > /tmp/mqtt-runtime/mosquitto.conf <<EOF
    listener 8883 0.0.0.0
    protocol mqtt

    allow_anonymous false
    password_file /tmp/mqtt-runtime/passwd
    acl_file ${acl}

    certfile /mosquitto/certs/fullchain.pem
    keyfile /mosquitto/certs/privkey.pem
    tls_version tlsv1.2

    persistence ${if mqtt.persistence then "true" else "false"}
    persistence_location /mosquitto/data/

    log_dest stdout
    EOF

    exec ${pkgs.mosquitto}/bin/mosquitto \
      -c /tmp/mqtt-runtime/mosquitto.conf
  '';

in
pkgs.dockerTools.buildLayeredImage {
  name = "pocketmeteo-mqtt";
  tag = "latest";

  contents = [
    pkgs.mosquitto
    pkgs.coreutils
    entrypoint
  ];

  config = {
    Entrypoint = [ "${entrypoint}/bin/start-mqtt" ];
    ExposedPorts = { "1883/tcp" = {}; };
    WorkingDir = "/";
    Volumes = { "/mosquitto/data" = {}; };
  };
}
