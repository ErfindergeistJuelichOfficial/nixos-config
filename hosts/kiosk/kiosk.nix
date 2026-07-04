{ pkgs, ... }:
let
  kioskUrl = "https://tasks.erfindergeist.org/share/45IADCnxFa1Bgts7Z6Eiu0rFybTCOroS4ecTZVzo/auth?view=20";

  kioskBrowser = pkgs.writeShellScript "kiosk-browser" ''
    exec ${pkgs.chromium}/bin/chromium \
      --kiosk \
      --start-fullscreen \
      --incognito \
      --noerrdialogs \
      --disable-infobars \
      --disable-session-crashed-bubble \
      --disable-translate \
      --no-first-run \
      --ozone-platform=wayland \
      --disk-cache-dir=/tmp/chromium-cache \
      --js-flags="--max-old-space-size=256" \
      "${kioskUrl}"
  '';
in
{
  services.cage = {
    enable = true;
    user = "kiosk";
    program = "${kioskBrowser}";
  };

  systemd.services.cage-tty1 = {
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
    environment = {
      # RPi 3 has VC4 (no Vulkan/v3dv); wlroots 0.18+ requires DRM+Vulkan to match.
      # Force GLES2 renderer which VC4 supports natively.
      WLR_RENDERER = "gles2";
      WLR_NO_HARDWARE_CURSORS = "1";
      WLR_RENDERER_ALLOW_SOFTWARE = "1";
      WLR_LIBINPUT_NO_DEVICES = "1";
    };
    after = [ "time-sync.target" "network-online.target" ];
    wants = [ "time-sync.target" "network-online.target" ];
  };

  # nightly restart at 04:00 to shed any slow memory leaks
  systemd.timers.kiosk-nightly-restart = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = false;
    };
  };
  systemd.services.kiosk-nightly-restart = {
    description = "Nightly restart of the kiosk browser";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart cage-tty1.service";
    };
  };

  users.users.kiosk = {
    isNormalUser = true;
  };

  hardware.graphics.enable = true;

  zramSwap.enable = true;

  boot.kernelParams = [ "consoleblank=0" ];
}
