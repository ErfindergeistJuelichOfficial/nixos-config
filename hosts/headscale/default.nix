{ config, modulesPath, lib, pkgs,  ... }:
let
  hostname = "headscale";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets."headscale/client-secret" = {
    owner = config.users.users.headscale.name;
    group = config.users.users.headscale.group;
  };

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # do not use DHCP, as dashserv provisions IPs using cloud-init (see service below)
  networking.useDHCP = pkgs.lib.mkForce false;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    #trustedInterfaces = [ "tailscale0" ];
  };

  networking.hostName = hostname;

  services.caddy = {
    enable = true;
    email = lib.strings.concatStrings [ "kontakt" "@" "erfindergeist.org" ];
    virtualHosts = {
      "headscale.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy localhost:${builtins.toString config.services.headscale.port}
        '';
      };
    };
  };

  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      hostname = hostname;
    };
  };

  services.fail2ban.enable = true;

  services.headscale = {
    enable = true;
    port = 8080;
    settings = {
      server_url = "https://headscale.erfindergeist.org:443";
      dns.base_domain = "tailnet.erfindergeist.org";
      policy.path = ./acl.jsonc;
      oidc = {
        issuer = "https://login.microsoftonline.com/194ff3aa-ddd4-4e8d-8173-6c4880b098db/v2.0";
        client_id = "3f5dad2f-2cd6-4d29-80fa-71f5191f6a09";
        client_secret_path = config.sops.secrets."headscale/client-secret".path;
        scope =  ["openid" "profile" "email"];
        extra_params = {
          domain_hint = "erfindergeist.org";
          prompt =  "select_account";
        };
      };
    };
  };

  services.tailscale.enable = true;

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
