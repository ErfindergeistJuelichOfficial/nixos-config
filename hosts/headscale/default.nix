{ modulesPath, pkgs, ... }:
let
  hostname = "headscale";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  environment.systemPackages = with pkgs; [
    headscale
    vim
  ];

  # do not use DHCP, as dashserv provisions IPs using cloud-init (see service below)
  networking.useDHCP = pkgs.lib.mkForce false;
  networking.firewall = {
    enable = true;
    #allowedTCPPorts = [ 80 443 ];
    #trustedInterfaces = [ "tailscale0" ];
  };

  networking.hostName = hostname;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ5bIn+kHUg9MKbmXVnCWOFCIAhbiKE1CrWMhdumcno9 rothe@pdemu1cml000301"
  ];

  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      hostname = hostname;
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    authorizedKeysInHomedir = false;
  };

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
      graphics = false;
    };
    services.getty.autologinUser = "root";
  };

  system.stateVersion = "24.11";
}
