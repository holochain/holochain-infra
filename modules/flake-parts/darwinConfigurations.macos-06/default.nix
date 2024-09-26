{
  self,
  lib,
  inputs,
  ...
}:
let
  system = "x86_64-darwin";
in
{
  flake.darwinConfigurations.macos-06 = inputs.darwin.lib.darwinSystem {
    inherit system inputs;
    inherit (self) specialArgs;
    modules = [
      ./configuration.nix
      ../../nixos/macos.nix
      ../../nixos/macos-remote-builder.nix
      inputs.home-manager.darwinModules.home-manager
    ];
  };
}
