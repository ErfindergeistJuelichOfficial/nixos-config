{ ... }:
{
  # TODO read https://github.com/orgs/opencloud-eu/discussions/1014
  # probably have to add KEYCLOAK_CLIENT_ID and KEYCLOAK_CLIENT_SECRET
  services.opencloud = let
    clientId = "opencloud"; # doc stated that only "web" is supported
  in {
    address = "0.0.0.0";
    enable = true;
    environment = {
      OC_EXCLUDE_RUN_SERVICES = "idp";
      OC_OIDC_ISSUER = "https://auth.erfindergeist.org/oauth2/openid/${clientId}";
      PROXY_TLS = "false";
      PROXY_INSECURE_BACKENDS = "true";
      PROXY_USER_OIDC_CLAIM = "preferred_username";
      WEB_HTTP_ADDR = "0.0.0.0:9101";
    };
    #environmentFile = "";
    port = 9292;
    url = "https://cloud.erfindergeist.org";
    settings = {
      csp = {
        directives = {
          connect-src = [
            "https://cloud.erfindergeist.org/"
            "https://auth.erfindergeist.org//"
          ];
          frame-src = [
            "https://cloud.erfindergeist.org/"
            "https://auth.erfindergeist.org//"
          ];
        };
      };
      proxy = {
        auto_provision_accounts = true;
        csp_config_file_location = "/etc/opencloud/csp.yaml";
        oidc = {
          rewrite_well_known = true;
        };
        role_assignment = {
          driver = "oidc";
          oidc_role_mapper = {
            role_claim = "groups";
          };
        };
        role_quotas = {
          # Grant users 20 GB
          # https://docs.opencloud.eu/docs/admin/configuration/default-user-quota#role-ids
          "d7beeea8-8ff4-406b-8fb6-ab2dd81e6b11" = 21474836480;
        };
      };
      settings = {
        default_language = "en";
      };
      web = {
        web = {
          config = {
            oidc = {
              authority = "https://auth.erfindergeist.org";
              metadata_url = "https://auth.erfindergeist.org/oauth2/openid/.well-known/openid-configuration";
              client_id = clientId;
              # response_type = "code";
              scope = "openid profile email groups";
              post_logout_redirect_uri = "";
            };
            apps = [
              "files"
              "search"
              "text-editor"
              "pdf-viewer"
              "preview"
              "app-store"
            ];
          };
        };
      };
    };
    stateDir = "/mnt/data/opencloud";
  };
}
