{
  description = "A flake describing erfindergeist systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, sops-nix, nixos-hardware }: {
    nixosConfigurations = {
      headscale = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules
          ./hosts/headscale
        ];
      };
      werkstatt-prodesk = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./modules
          ./hosts/werkstatt-prodesk
        ];
      };
      werkstatt-workstation = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules
          ./hosts/werkstatt-workstation
        ];
      };
      vikunja-kiosk = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-3
          ./hosts/kiosk
        ];
      };
    };

    packages.x86_64-linux.default = self.nixosConfigurations.headscale.config.system.build.vm;
    packages.x86_64-linux.werkstatt-prodesk = self.nixosConfigurations.werkstatt-prodesk.config.system.build.vm;
    packages.x86_64-linux.werkstatt-workstation = self.nixosConfigurations.werkstatt-workstation.config.system.build.vm;
    packages.aarch64-linux.vikunja-kiosk = self.nixosConfigurations.vikunja-kiosk.config.system.build.sdImage;
  };
}
