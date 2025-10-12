{ config, pkgs, ... }:
{
  config = {
    sops.secrets."nextcloud/adminPass" = {};
    sops.templates."adminPassFile".content = config.sops.placeholder."nextcloud/adminPass";
    services.nextcloud = {
      enable = true;

      # Need to manually increment with every major upgrade.
      package = pkgs.nextcloud31;

      caching.redis = true;
      configureRedis = true;

      database.createLocally = true;
      datadir = "/mnt/data/nextcloud";


      hostName = "cloud.erfindergeist.org";
      maxUploadSize = "4G";

      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit polls tables user_oidc;  # onlyoffice
      };

      config = {
        overwriteProtocol = "https";
        dbtype = "pgsql";
        adminuser = "verein";
        adminpassFile = config.sops.templates."adminPassFile".path;
      };
    };

    #onlyoffice = {
    #  enable = true;
    #  hostname = "onlyoffice.example.com";
    #};
  };

}
