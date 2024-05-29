{
  self,
  lib,
  inputs,
  ...
}: let
  system = "aarch64-darwin";
in {
  flake.darwinConfigurations.macos-03 = inputs.darwin.lib.darwinSystem {
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
