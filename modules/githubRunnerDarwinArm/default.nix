{ self, lib, inputs, config, ... }: {
  perSystem = { config, self', inputs', pkgs, ... }: {
    apps."deploy-macos-01" = {
      type = "app";
      program = toString (config.mkDarwinDeploy {
        inherit (import ./attrs.nix) hostName;
        attrName = "githubRunnerDarwinArm01";
      });
    };
  };
  flake.darwinConfigurations.githubRunnerDarwinArm01 = inputs.darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [
      ./configuration.nix
      self.modules.darwin.github-runners
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




