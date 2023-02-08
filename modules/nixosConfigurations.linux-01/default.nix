{
  self,
  lib,
  inputs,
  config,
  ...
}: {
  flake.nixosConfigurations.linux-01 = let
    system = "x86_64-linux";
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        self.nixosModules.holo-users
      ];

      specialArgs = {
        inherit inputs;
      };
    };
}
