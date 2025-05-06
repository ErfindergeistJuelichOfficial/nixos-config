{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    # Necessary for incus to masquerade properly
    "net.ipv4.conf.all.forwarding" = "1";
  };

  networking.hostName = "werkstatt-prodesk";
  systemd.network.enable = true;
  services.resolved.enable = true;
  systemd.services."systemd-networkd-wait-online".enable = lib.mkForce false;

  system.autoUpgrade = {
    enable = true;
    flake = "github:ErfindergeistJuelichOfficial/nixos-config#${config.networking.hostName}";
    flags = [
      "--no-write-lock-file"
    ];
    allowReboot = true;
    dates = "daily";
  };

  networking.nftables.enable = true;
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" "incusbr0" ];
    allowedTCPPorts = [ 8123 ];
  };

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de";

  documentation = {
    man.enable = false;
    nixos.enable = false;
    dev.enable = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  users.mutableUsers = false;
  users.users.root.hashedPassword = "$6$AE1yIgu1pprXS5jC$0MzA4Qmnuqnz789IhsLw4QEaGc1CXiOp4W3tjpQhbhH96qp7ar8NjVSe22mucZCiAoUT/o4BSU3Zq6r9.l6Z20";
  users.users.erfindergeist = {
    isNormalUser = true;
    hashedPassword =
      "$6$bfECpU8Vvxqk05ar$96z1Zaj7dtrCzuA1RMT7JRFXvq79WzS.Hfr9xqhrcxM2kvp.gy1jWunqEhsng6P4XH1gOr.3i7.A72f7gbXel/";
    description = "erfindergeist";
    extraGroups = [ "incus-admin" ];
  };

  services.tailscale.enable = true;

  services.caddy = {
    enable = true;
    virtualHosts = {
      ":8123" = {
        extraConfig = ''
          reverse_proxy 10.147.121.6:8123 {
            header_up Host {upstream_hostport}
          }
        '';
      };
    };
  };

  virtualisation.incus = {
    enable = true;
    ui.enable = true;
  };

  environment.systemPackages = with pkgs; [
    curl
    htop
    vim
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
