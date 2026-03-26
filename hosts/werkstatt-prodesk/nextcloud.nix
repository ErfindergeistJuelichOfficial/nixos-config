{ config, pkgs, ... }:
{
  config = let
    hostname = "cloud.erfindergeist.org";
  in {
    sops.secrets."nextcloud/adminPass" = {};
    sops.templates."adminPassFile".content = config.sops.placeholder."nextcloud/adminPass";
    services.nextcloud = {
      enable = true;

      # Need to manually increment with every major upgrade.
      package = pkgs.nextcloud32;


      config = {
        dbtype = "pgsql";
        adminuser = "verein";
        adminpassFile = config.sops.templates."adminPassFile".path;
      };

      caching.redis = true;
      configureRedis = true;

      database.createLocally = true;
      datadir = "/mnt/data/nextcloud";


      hostName = hostname;
      maxUploadSize = "4G";

      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar forms groupfolders polls user_oidc;
        passwords = pkgs.fetchNextcloudApp {
          url = "https://git.mdns.eu/api/v4/projects/45/packages/generic/passwords/2026.3.0/passwords.tar.gz";
          sha256 = "sha256-YHilpFaZHNCtqLRvTCDhyVoFWLC85Qkj1mMxp08YCho=";
          license = "agpl3Only";
        };
      };

      settings = {
        "overwriteprotocol" = "https";
        "overwrite.cli.url" = "https://cloud.erfindergeist.org";
        trusted_domains = [
          hostname
        ];
        trusted_proxies = [
          "100.64.0.0/10"
        ];
      };
    };
  };

}
