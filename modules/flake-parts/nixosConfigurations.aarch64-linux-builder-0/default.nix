{
  self,
  lib,
  inputs,
  ...
}:
let
  evaluatedSystem = inputs.nixpkgsUnstable.lib.nixosSystem {
    modules = [ ./configuration.nix ];
    system = "aarch64-linux";
    specialArgs = self.specialArgs;
  };
in
{
  flake.nixosConfigurations."${evaluatedSystem.config.passthru.hostName}" = evaluatedSystem;
}
