{ config, lib, ... }:
{
  options.erfindergeist.services.cache = {
    enable = lib.mkEnableOption "Erfindergeist Cachix binary cache";
  };

  config = lib.mkIf config.erfindergeist.services.cache.enable {
    nix.settings = {
      substituters = [
        "https://erfindergeist.cachix.org/"
      ];
      trusted-public-keys = [
        "erfindergeist.cachix.org-1:oC+SlMxjsC+BNTtWryDXx9piQMjPSJAe0ahMdE6BRAg="
      ];
    };
  };
}
