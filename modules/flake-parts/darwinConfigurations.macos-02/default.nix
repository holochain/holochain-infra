{
  self,
  lib,
  inputs,
  config,
  ...
}: let
  system = "x86_64-darwin";
in {
  flake.darwinConfigurations.macos-02 = inputs.darwin.lib.darwinSystem {
    inherit system inputs;
    modules = [
      ./configuration.nix
      ../../nixos/macos.nix
      ../../nixos/macos-remote-builder.nix
      inputs.home-manager.darwinModules.home-manager
    ];
  };
}
