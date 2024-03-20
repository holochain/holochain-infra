{
  lib,
  inputs,
  ...
}: let
  system = "aarch64-darwin";
in {
  flake.darwinConfigurations.macos-01 = inputs.darwin.lib.darwinSystem {
    inherit system inputs;
    modules = [
      ./configuration.nix
      ../../nixos/macos.nix
      ../../nixos/macos-remote-builder.nix
      inputs.home-manager.darwinModules.home-manager
    ];
  };
}
