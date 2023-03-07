{
  self,
  lib,
  inputs,
  config,
  ...
}: let
  system = "aarch64-darwin";
in {
  flake.darwinConfigurations.macos-01 = inputs.darwin.lib.darwinSystem {
    inherit system;
    modules = [
      ./configuration.nix
      ./remote-builder.nix
      ../../nixos/macos.nix
      ../../nixos/shared.nix
      ../../nixos/shared-nix-settings.nix
      inputs.home-manager.darwinModules.home-manager
      {
        # `home-manager` config
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.hetzner = import ./home.nix;
      }
    ];

    specialArgs = {
      inherit inputs;
    };
  };
}
