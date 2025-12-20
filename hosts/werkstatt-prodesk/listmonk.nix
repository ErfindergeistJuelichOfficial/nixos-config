{ ... }:
let
  port = "9900";
in {
  services.listmonk = {
    enable = true;
    database.createLocally = true;
    settings.app.address = "100.64.0.12:${port}";
  };
  services.borgmatic.configurations.databases.postgresql_databases = [
    { name = "listmonk"; username = "listmonk"; }
  ];
}
