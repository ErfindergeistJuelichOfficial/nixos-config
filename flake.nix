{
  description = "A flake describing erfindergeist systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, sops-nix }: {
    nixosConfigurations = {
      headscale = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/headscale
        ];
      };
      werkstatt-prodesk = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./hosts/werkstatt-prodesk
        ];
      };
      werkstatt-workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/werkstatt-workstation
        ];
      };
    };

    packages.x86_64-linux.default = self.nixosConfigurations.headscale.config.system.build.vm;
    packages.x86_64-linux.werkstatt-prodesk = self.nixosConfigurations.werkstatt-prodesk.config.system.build.vm;
    packages.x86_64-linux.werkstatt-workstation = self.nixosConfigurations.werkstatt-workstation.config.system.build.vm;
  };
}
