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

  documentation = {
    man.enable = false;
    nixos.enable = false;
    dev.enable = false;
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:ErfindergeistJuelichOfficial/nixos-config#headscale";
    flags = [
      "--no-write-lock-file"
    ];
    allowReboot = true;
    dates = "daily";
  };

  # do not use DHCP, as dashserv provisions IPs using cloud-init (see service below)
  networking.useDHCP = pkgs.lib.mkForce false;
  networking.nftables.enable = true;
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
      "n8n.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy 192.168.100.11:8000
        '';
      };
      "auth.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy 192.168.100.11:8001
        '';
      };
      "tasks.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy 192.168.100.11:8002
        '';
      };
      "docs.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy 192.168.100.11:8003
        '';
      };
      "social.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy 192.168.100.11:8004
        '';
      };
      "cloud.erfindergeist.org" = {
        extraConfig = ''
          reverse_proxy 192.168.100.11:8005
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
      dns.override_local_dns = false;
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

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-*" ];
    externalInterface = "eth0";
  };

  containers.headscale-caddy = {
    autoStart = true;
    privateNetwork = true;
    enableTun = true; # necessary for tailscale
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.11";
    config = { ... }: {
      networking = {
        useHostResolvConf = lib.mkForce false;
        nftables.enable = true;
        firewall = {
          enable = true;
          allowedTCPPorts = [
            8000
            8001
            8002
            8003
            8004
            8005
          ];
        };
      };
      services.resolved.enable = true;

      services.tailscale.enable = true;
      services.caddy = {
        enable = true;
        virtualHosts = {
          ":8000" = {
            extraConfig = ''
              reverse_proxy werkstatt-prodesk:5678
            '';
          };
          ":8001" = {
            extraConfig = ''
              reverse_proxy https://werkstatt-prodesk:8444 {
                transport "http" {
                  tls_insecure_skip_verify
                }
              }
            '';
          };
          # vikunja
          ":8002" = {
            extraConfig = ''
              reverse_proxy http://werkstatt-prodesk:3456
            '';
          };
          # outline
          ":8003" = {
            extraConfig = ''
              reverse_proxy http://werkstatt-prodesk:3000
            '';
          };
          # gotosocial
          ":8004" = {
            extraConfig = ''
              reverse_proxy http://werkstatt-prodesk:8080
            '';
          };
          # nextcloud
          ":8005" = {
            extraConfig = ''
              reverse_proxy http://werkstatt-prodesk:80
            '';
          };
        };
      };

      system.stateVersion = "25.11";
    };
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
