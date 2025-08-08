{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #sops.defaultSopsFile = ./secrets.yaml;
  #sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  #services = {
  #  displayManager.gdm.enable = true;
  #  desktopManager.gnome.enable = true;
  #};


  networking.hostName = "werkstatt-workstation";
  systemd.network.enable = true;
  services.resolved.enable = true;
  services.resolved.extraConfig = ''
    MulticastDNS=resolve;
  '';
  systemd.services."systemd-networkd-wait-online".enable = lib.mkForce false;

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "enp1s0";
    networkConfig.DHCP = "ipv4";
    dhcpV4Config.UseDomains = true;
    networkConfig = {
      MulticastDNS = true;
    };
  };

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
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [
      5353  # mDNS
    ];
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
  users.users.root = {
    # TODO adapt
    hashedPassword = "$6$AE1yIgu1pprXS5jC$0MzA4Qmnuqnz789IhsLw4QEaGc1CXiOp4W3tjpQhbhH96qp7ar8NjVSe22mucZCiAoUT/o4BSU3Zq6r9.l6Z20";
  };

  services.tailscale.enable = true;

  services.kanidm = {
    enableClient = true;
    package = pkgs.kanidm_1_6;
    clientSettings.uri = "https://auth.erfindergeist.org";
  };

  environment.systemPackages = with pkgs; [
    curl
    htop
    vim
  ];

  # Special config for launching the VM variant
  virtualisation.vmVariant = {
    virtualisation = {
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
      graphics = true;
    };
    services.getty.autologinUser = "root";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
