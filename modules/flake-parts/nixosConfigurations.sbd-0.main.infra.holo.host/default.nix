{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.sbd-0_main_infra_holo_host = inputs.nixpkgs.lib.nixosSystem {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
