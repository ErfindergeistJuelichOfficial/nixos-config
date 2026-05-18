{ pkgs, ... }:
{
  systemd.services.podman-network-unifi = {
    description = "Create podman network for UniFi";
    before = [ "podman-unifi-db.service" "podman-unifi.service" ];
    requiredBy = [ "podman-unifi-db.service" "podman-unifi.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.podman}/bin/podman network exists unifi || \
        ${pkgs.podman}/bin/podman network create unifi
    '';
  };

  virtualisation.oci-containers.containers = {
    unifi-db = {
      image = "mongo:7.0@sha256:4b5bf3c2bb7516164f6dcb44acce4fdcb428abfe5771a1128304a0f34ab9ff7c";
      volumes = [ "/var/lib/unifi-db:/data/db" ];
      extraOptions = [ "--network=unifi" ];
    };

    unifi = {
      image = "lscr.io/linuxserver/unifi-network-application:10.3.58@sha256:b01b8b127fd0dea381199958539eaae82dce10f9a23dab0c5cbfc836001cc7e0";
      volumes = [ "/var/lib/unifi:/config" ];
      environment = {
        MONGO_HOST = "unifi-db";
        MONGO_PORT = "27017";
        MONGO_DBNAME = "unifi";
        MEM_LIMIT = "1024";
        MEM_STARTUP = "1024";
      };
      ports = [
        "8080:8080"        # UniFi device inform
        "8443:8443"        # Web UI (also reachable via Tailscale)
        "3478:3478/udp"    # UniFi STUN
        "10001:10001/udp"  # UniFi L2 device discovery
      ];
      extraOptions = [ "--network=unifi" ];
      dependsOn = [ "unifi-db" ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      8080  # UniFi device inform
    ];
    allowedUDPPorts = [
      3478   # UniFi STUN
      10001  # UniFi L2 device discovery
    ];
  };
}
