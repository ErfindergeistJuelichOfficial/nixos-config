{ lib, ... }:
{
  # sd-image-aarch64 creates NIXOS_SD as a full rootfs (with /nix/store inside),
  # so it must be mounted at / — not at /nix — or the initrd can't find the closure.
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  # Boot/firmware partition is read-only after the kernel is loaded.
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "ro" "noatime" ];
  };

  # /tmp is already tmpfs via this option; Chromium cache is pointed there.
  boot.tmp.useTmpfs = true;

  # Keep logs in RAM only — no writes to SD card.
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
  '';

  # No swap on disk (would require a writable partition).
  # zramSwap is enabled in kiosk.nix instead.
  swapDevices = [];

  # BCM2835 hardware watchdog — power-cycles on a hung kernel.
  boot.kernelModules = [ "bcm2835_wdt" ];
  systemd.settings.Manager.RuntimeWatchdogSec = "30s";

  # No ZFS on this device; silence the forceImportRoot warning.
  boot.zfs.forceImportRoot = false;
}
