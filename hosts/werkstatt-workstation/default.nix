{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot = {
    loader.grub.enable = true;
    loader.grub.device = "/dev/sda";

    plymouth = {
      enable = true;
      theme = "circle";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "circle" ];
        })
      ];
    };
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];
    loader.timeout = 1;
  };


  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };


  networking = {
    hostName = "werkstatt-workstation";
    interfaces."enp12s0".wakeOnLan.enable = true;
  };
  systemd = {
    network.enable = true;
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

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
    allowedUDPPorts = [
      5353  # mDNS
    ];
    trustedInterfaces = [
      "tailscale0"
    ];
  };

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de";

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

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

  users.mutableUsers = true;
  users.users.erfindergeist = {
    isNormalUser = true;
    group = "erfindergeist";
    description = "Erfindergeist";
    extraGroups = [ "networkmanager" "wheel" "podman" ];
    hashedPassword = "$y$j9T$dO7c2cphx1q5oDw.bIcLP1$kcon910nDQMQWjcPT3tFPgmPIsmlT6HrqSde8S71UG6";
  };
  users.groups.erfindergeist = {};

  users.users.root = {
    hashedPassword = "$y$j9T$dO7c2cphx1q5oDw.bIcLP1$kcon910nDQMQWjcPT3tFPgmPIsmlT6HrqSde8S71UG6";
  };

  services.tailscale.enable = true;

  #services.kanidm = {
  #  package = pkgs.kanidm_1_7;
  #  enableClient = true;
  #  clientSettings.uri = "https://auth.erfindergeist.org";
  #  enablePam = true;
  #  unixSettings = {
  #    pam_allowed_login_groups = [ config.networking.hostName ];
  #  };
  #};

  # Remote desktop
  services = {
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
    };
    gnome.gnome-remote-desktop.enable = true;
  };

  environment.systemPackages = with pkgs; [
    bash
    curl
    eog
    evince
    firefox
    gedit
    gimp
    git
    htop
    inkscape
    libreoffice
    neovim
    orca-slicer
    prusa-slicer
    totem
    vim
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode-with-extensions"
    "vscode"
  ];
  programs.vscode.enable = true;

  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # Special config for launching the VM variant
  virtualisation.vmVariant = {
    virtualisation = {
      qemu.guestAgent.enable = true;
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
  system.stateVersion = "25.05"; # Did you read the comment?
}
