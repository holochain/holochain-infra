{ self, lib, inputs, config, ... }:
let
  system = "aarch64-darwin";

in
{
  flake.darwinConfigurations.macos-01 = inputs.darwin.lib.darwinSystem {
    inherit system;
    modules = [
      ./configuration.nix
      ./remote-builder.nix
      ../../shared.nix
      ../../shared-nix-settings.nix
      self.modules.darwin.github-runners-tart
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
