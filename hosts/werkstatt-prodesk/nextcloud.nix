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
        inherit calendar forms groupfolders polls user_oidc;  # onlyoffice
      };

      settings = {
        overwriteprotocol = "https";
        trusted_domains = [
          hostname
        ];
        trusted_proxies = [
          "100.64.0.14"
        ];
      };
    };
  };

}
