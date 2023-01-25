{ self, lib, inputs, config, ... }: {

  flake.darwinConfigurations.macos-01 = inputs.darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [
      ./configuration.nix
      self.modules.darwin.github-runners
      self.modules.darwin.github-runners-tart
      inputs.home-manager.darwinModules.home-manager
      {
        # `home-manager` config
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.hetzner = import ./home.nix;
      }
    ];
  };
}




