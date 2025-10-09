{ ... }:
{
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    loadModels = ["gemma3:12b" "qwen2.5-coder:14b"];
  };

  nixpkgs.config.packageOverrides = pkgs: {
    ollama = pkgs.ollama.override {
      cudaArches = [ "61" ];
    };
  };

  services.open-webui = {
    enable = true;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      ENABLE_VERSION_UPDATE_CHECK = "False";
    };
  };
}
