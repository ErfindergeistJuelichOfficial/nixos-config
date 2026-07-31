{ config, pkgs, ... }:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda.override {
      cudaArches = [ "120" ];
    };
    loadModels = [
      "gemma4:12b"
      "qwen3.5:4b"
      "qwen3.5:9b"
    ];
  };

  sops.secrets."openwebui/clientsecret" = {
    restartUnits = [ "open-webui.service" ];
  };
  sops.templates."openwebuiEnv".content = ''
    OAUTH_CLIENT_SECRET=${config.sops.placeholder."openwebui/clientsecret"}
  '';

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    environmentFile = config.sops.templates."openwebuiEnv".path;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      ENABLE_VERSION_UPDATE_CHECK = "False";
      ENABLE_OAUTH_SIGNUP = "True";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
      OAUTH_PROVIDER_NAME = "Erfindergeist SSO";
      OPENID_PROVIDER_URL = "https://auth.erfindergeist.org/oauth2/openid/openwebui";
      OAUTH_CLIENT_ID = "openwebui";
      OAUTH_SCOPES = "openid profile email";
    };
  };
}
