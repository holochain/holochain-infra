{ lib, inputs, config, ... }: {
  perSystem = { config, self', inputs', pkgs, ... }: {
    apps."deploy-linux-01" = {
      type = "app";
      program = toString (config.mkLinuxDeploy {
        inherit (import ./attrs.nix) hostName;
        attrName = "linux-01";
      });
    };
  };

  flake.nixosConfigurations.linux-01 = let

    magicPaths = {
      githubRunnerHraTokenHostPath = "/var/secrets/github-runner/hra2.token";
      githubRunnerHraTokenMountPoint = "/secrets/github-runner/token";
    };

    githubRunnerContainerPathFn = name: extraLabels: let
      nixos = inputs.nixpkgs-github-runner.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixos-containers/github-runner/configuration.nix
        ];

        specialArgs = {
          githubRunnerHolochainHolochainTokenFile = magicPaths.githubRunnerHraTokenMountPoint;
          inherit name extraLabels;
        };
      };
    in
      nixos.config.system.build.toplevel;

  in inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
    ];

    specialArgs = {
      inherit githubRunnerContainerPathFn;
      # githubRunnerContainerPath = githubRunnerContainer.config.system.build.toplevel;
      githubRunnerContainerNixpkgs = inputs.nixpkgs-github-runner;

      inherit (magicPaths)
        githubRunnerHraTokenHostPath
        githubRunnerHraTokenMountPoint
        ;

      extraAuthorizedKeyFiles = config.sshKeysAll;
    };
  };
}
