# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports = [
    mqtt.nix
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  environment.systemPackages = with pkgs; [
    git
    wakeonlan
  ];

  services.netbird = {
    enable = true;
    useRoutingFeatures = "both";
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.firewall.allowedTCPPorts = [ 22 51820 ];
  networking.firewall.trustedInterfaces = [ "wt0" ];


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      PermitRootLogin = "yes"; # При использовании замените на более сложный.
    };
  };

  system.stateVersion = "26.05"; # Did you read the comment?

}

