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
    inherit system;
    modules = [
      ./configuration.nix
      ../../nixos/macos.nix
      ../../nixos/macos-remote-builder.nix
      ../../nixos/shared.nix
      ../../nixos/shared-nix-settings.nix
      inputs.home-manager.darwinModules.home-manager
    ];

    specialArgs = {
      inherit inputs;
    };
  };
}
