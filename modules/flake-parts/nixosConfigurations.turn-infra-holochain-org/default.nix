{
  config,
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.turn-infra-holochain-org = inputs.nixpkgs.lib.nixosSystem {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
