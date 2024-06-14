{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.x86_64-linux-dev-01 = inputs.nixpkgs.lib.nixosSystem {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
