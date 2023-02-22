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
      ./remote-builder.nix
      ../../nixos/shared.nix
      ../../nixos/shared-nix-settings.nix
      inputs.home-manager.darwinModules.home-manager
      {
        # `home-manager` config
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.administrator = import ./home.nix;
      }
    ];

    specialArgs = {
      inherit inputs;
    };
  };
}
