{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.linux-builder-02 = inputs.nixpkgs.lib.nixosSystem {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
