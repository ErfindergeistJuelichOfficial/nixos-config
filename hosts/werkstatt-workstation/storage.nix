{ ... }:
let
  dataDir = "/data";
in
{
  # Second SSD (Intenso 120 GB) for large model files.
  fileSystems.${dataDir} = {
    device = "/dev/disk/by-uuid/2561817c-4e7d-4140-9693-92acda04f173";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # Bind the subdirectories to where the services expect their state.
  fileSystems."/var/lib/comfyui" = {
    device = "${dataDir}/comfyui";
    fsType = "none";
    options = [ "bind" "nofail" ];
    depends = [ dataDir ];
  };

  # ollama uses DynamicUser, so its state lives in /var/lib/private/ollama.
  fileSystems."/var/lib/private/ollama" = {
    device = "${dataDir}/ollama";
    fsType = "none";
    options = [ "bind" "nofail" ];
    depends = [ dataDir ];
  };

  systemd.services.ollama.unitConfig.RequiresMountsFor = "/var/lib/private/ollama";
}
