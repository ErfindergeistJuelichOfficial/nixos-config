{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    # Necessary for incus to masquerade properly
    "net.ipv4.conf.all.forwarding" = "1";
  };

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  networking.hostName = "werkstatt-prodesk";
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
    trustedInterfaces = [ "tailscale0" "incusbr0" ];
    allowedTCPPorts = [
      22   # SSH
      8123 # Home Assistant
    ];
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
    hashedPassword = "$6$AE1yIgu1pprXS5jC$0MzA4Qmnuqnz789IhsLw4QEaGc1CXiOp4W3tjpQhbhH96qp7ar8NjVSe22mucZCiAoUT/o4BSU3Zq6r9.l6Z20";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLg8qmYBZzk9inPEEAlacDj7v5uUdTEqcs1jc+J1fuJ rothe@lift"
    ];
  };

  users.users.erfindergeist = {
    isNormalUser = true;
    hashedPassword =
      "$6$bfECpU8Vvxqk05ar$96z1Zaj7dtrCzuA1RMT7JRFXvq79WzS.Hfr9xqhrcxM2kvp.gy1jWunqEhsng6P4XH1gOr.3i7.A72f7gbXel/";
    description = "erfindergeist";
    extraGroups = [ "incus-admin" ];
  };

  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      AllowUsers = null; # Allows all users by default.
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
    };
  };

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

  services.apcupsd.enable = true;

  services.kanidm = {
    #enableClient = true;
    enableServer = true;
    package = pkgs.kanidm_1_6;
    #clientSettings.uri = "https://127.0.0.1:8444";
    serverSettings = {
      domain = "auth.erfindergeist.org";
      origin = "https://auth.erfindergeist.org";
      bindaddress = "0.0.0.0:8444";
      ldapbindaddress = "127.0.0.1:3636";
      # https://kanidm.github.io/kanidm/stable/evaluation_quickstart.html#generate-evaluation-certificates
      tls_key = "/etc/kanidm/key.pem";
      tls_chain = "/etc/kanidm/chain.pem";
      online_backup = {
        path = "/var/lib/kanidm/backups";
        schedule = "00 22 * * *";
        versions = 7;
      };
    };
  };

  sops.secrets."vikunja/clientsecret" = {};
  sops.templates."vikunja.yaml".content = ''
    auth:
      local:
        enabled: false
      openid:
        enabled: true
        providers:
        - authurl: https://auth.erfindergeist.org/oauth2/openid/vikunja
          clientid: vikunja
          clientsecret: ${config.sops.placeholder."vikunja/clientsecret"}
          name: kandidm
          scope: openid profile email
    database:
      database: vikunja
      host: localhost
      path: /var/lib/vikunja/vikunja.db
      type: sqlite
      user: vikunja
    files:
      basepath: /var/lib/vikunja/files
    service:
      frontendurl: https://tasks.erfindergeist.org/
      interface: :3456
  '';
  users.users.vikunja = {
    group = "vikunja";
    isSystemUser = true;
  };
  users.groups.vikunja = {};
  environment.etc."vikunja/config.yaml".source = lib.mkForce config.sops.templates."vikunja.yaml".path;
  sops.templates."vikunja.yaml".owner = "vikunja";

  systemd.services.vikunja.serviceConfig = {
    User = "vikunja";
    Group = "vikunja";
    DynamicUser = lib.mkForce false;
  };

  services.vikunja = {
    enable = true;
    frontendHostname = "tasks.erfindergeist.org";
    frontendScheme = "https";
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

  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      n8n = {
        environment = {
          N8N_RUNNERS_ENABLED = "true";
          N8N_EDITOR_BASE_URL = "https://n8n.erfindergeist.org";
        };
        image = "ghcr.io/n8n-io/n8n:1.103.2";
        ports = [ "5678:5678" ];
        volumes = [ "n8n_data:/home/node/.n8n" ];
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
