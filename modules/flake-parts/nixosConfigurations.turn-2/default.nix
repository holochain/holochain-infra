{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.turn-2 = inputs.nixpkgs.lib.nixosSystem {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
