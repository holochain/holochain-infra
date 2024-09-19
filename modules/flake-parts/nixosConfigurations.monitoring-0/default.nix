{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.monitoring-0 = inputs.nixpkgs.lib.nixosSystem {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
