{ pkgs, lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    ./kiosk.nix
    ./readonly.nix
    ./remote.nix
  ];

  networking.hostName = "vikunja-kiosk";
  networking.useDHCP = true;
  networking.nftables.enable = true;

  networking.interfaces.eth0.useDHCP = true;

  hardware.enableRedistributableFirmware = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "Europe/Berlin";

  documentation = {
    man.enable = false;
    nixos.enable = false;
    dev.enable = false;
  };

  users.mutableUsers = false;

  system.stateVersion = "26.05";
}
