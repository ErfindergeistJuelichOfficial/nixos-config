{ lib, ... }:
let
  dataDir = "/var/lib/comfyui";
  port = 8188;
in
{
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.vmVariant = {
    hardware.nvidia-container-toolkit.enable = lib.mkVMOverride false;
    virtualisation.oci-containers.containers.comfyui.autoStart = lib.mkVMOverride false;
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers.comfyui = {
      # Blackwell / RTX 50xx (sm_120, cudaArches "120") braucht CUDA >= 12.8.
      # Gewählt: yanwk/comfyui-boot:cu130-megapak-pt211 (CUDA 13.0 + PyTorch 2.11,
      # aktiv gepflegt, Stand 2026-07-31, ~12.4 GB). Per Digest gepinnt für Reproduzierbarkeit.
      # Aktualisieren: neuen Digest holen mit
      #   skopeo inspect docker://docker.io/yanwk/comfyui-boot:cu130-megapak-pt211 | jq -r .Digest
      image = "docker.io/yanwk/comfyui-boot@sha256:35e8e39d2656bfac2e749690e75338b855c94b0d4547bac90a8119df34988b89";
      autoStart = true;

      volumes = [
        "${dataDir}:/root"
      ];

      ports = [
        "127.0.0.1:${toString port}:8188"
      ];

      extraOptions = [
        "--device=nvidia.com/gpu=all"
      ];
    };
  };

  systemd.services."podman-comfyui" = {
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
  };
}
