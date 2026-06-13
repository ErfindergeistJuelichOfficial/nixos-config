{ pkgs, ... }:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda.override {
      cudaArches = [ "61" ];
    };
    loadModels = [
      "gemma4:12b"
      "qwen3.5:4b"
      "qwen3.5:9b"
    ];
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
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
