{ config, pkgs, ... }:
let
  publicUrl = "https://openwebui.erfindergeist.org";
in
{
  services.ollama = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
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
  sops.templates."openwebuiEnv" = {
    restartUnits = [ "open-webui.service" ];
    content = ''
      OAUTH_CLIENT_SECRET=${config.sops.placeholder."openwebui/clientsecret"}
    '';
  };

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
      WEBUI_URL = publicUrl;
      # Without this, models that have no row in the model table count as
      # "unconfigured" and are admin-only, so SSO users see an empty list.
      BYPASS_MODEL_ACCESS_CONTROL = "True";
      DEFAULT_USER_ROLE = "user";
      ENABLE_OAUTH_SIGNUP = "True";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
      OAUTH_PROVIDER_NAME = "Erfindergeist SSO";
      OPENID_PROVIDER_URL = "https://auth.erfindergeist.org/oauth2/openid/openwebui/.well-known/openid-configuration";
      OPENID_REDIRECT_URI = "${publicUrl}/oauth/oidc/callback";
      OAUTH_CLIENT_ID = "openwebui";
      OAUTH_SCOPES = "openid profile email";
      OAUTH_CODE_CHALLENGE_METHOD = "S256";
    };
  };
}
