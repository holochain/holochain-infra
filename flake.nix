{
  description = "An example NixOS configuration";

  inputs = rec {
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    # nixpkgs-github-runner = { url = "github:nixos/nixpkgs/941c79b6207fa84612b4170ca3bc04984f3d79fc"; };
    nixpkgs-github-runner = nixpkgs-unstable;
  };

  outputs = inputs: {
    magicPaths = {
      githubRunnerHraTokenHostPath = "/var/secrets/github-runner/hra2.token";
      githubRunnerHraTokenMountPoint = "/secrets/github-runner/token";
    };

    nixosConfigurations = rec {
      githubRunnerContainerPathFn = name: extraLabels: (inputs.nixpkgs-github-runner.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixos-containers/github-runner/configuration.nix
        ];

        specialArgs = {
          githubRunnerHolochainHolochainTokenFile = inputs.self.magicPaths.githubRunnerHraTokenMountPoint;
          inherit name extraLabels;
        };
      }).config.system.build.toplevel;

      githubRunnerHost = inputs.nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixos-hosts/github-runner-host/configuration.nix
        ];

        specialArgs = {
          inherit githubRunnerContainerPathFn;
          # githubRunnerContainerPath = githubRunnerContainer.config.system.build.toplevel;
          githubRunnerContainerNixpkgs = inputs.nixpkgs-github-runner;

          inherit (inputs.self.magicPaths)
            githubRunnerHraTokenHostPath
            githubRunnerHraTokenMountPoint
            ;
        };
      };
    };
  };
}

