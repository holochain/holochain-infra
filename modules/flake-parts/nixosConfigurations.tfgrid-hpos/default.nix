{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.tfgrid-hpos = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      ./configuration.nix
      ];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
