{ config, lib, ... }: {
  services.borgmatic =
    let
      backupPath = "/mnt/backup";  # sshfs mount
      commonSettings = {
        compression = "lz4";
        archive_name_format = "backup-{now}";
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
        keep_yearly = 1;
        check_last = 3;
      };
    in
    {
      enable = true;
      # After a new installation
      #  * Run `nix run nixpkgs#borgmatic -- init --encryption repokey-blake2` to initialize the repos
      #  * Generate and add ssh key to all-inkl
      configurations = {
        files = lib.recursiveUpdate commonSettings {
          source_directories = [
            "/mnt/data/nextcloud"
          ];
          repositories = [
            {
              path = "${backupPath}/files";
              label = "files";
            }
          ];
        };

        databases = lib.recursiveUpdate commonSettings {
          source_directories = lib.mkForce [ ]; # Should never be set for the databases repo
          postgresql_databases = [
            {
              name = "nextcloud";
              username = "nextcloud";
            }
          ];
          repositories = [
            {
              path = "${backupPath}/databases";
              label = "databases";
            }
          ];
        };
      };
    };

  sops.secrets."borg/passphrase" = {};
  systemd.services.borgmatic = {
    environment = {
      BORG_PASSCOMMAND = "cat ${config.sops.secrets."borg/passphrase".path}";
    };
  };
}
