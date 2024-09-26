{
  self,
  lib,
  inputs,
  ...
}:
{
  flake.nixosConfigurations.linux-builder-01 = inputs.nixpkgs.lib.nixosSystem rec {
    modules = [ ./configuration.nix ];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
