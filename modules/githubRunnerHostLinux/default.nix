{ lib, inputs, config, ... }: {
  flake.nixosConfigurations.githubRunnerHost = let

    githubRunnerContainerPathFn = name: extraLabels: let
      nixos = inputs.nixpkgs-github-runner.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixos-containers/github-runner/configuration.nix
        ];

        specialArgs = {
          githubRunnerHolochainHolochainTokenFile = config.magicPaths.githubRunnerHraTokenMountPoint;
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

      inherit (config.magicPaths)
        githubRunnerHraTokenHostPath
        githubRunnerHraTokenMountPoint
        ;

      extraAuthorizedKeyFiles = config.sshKeysAll;
    };
  };
}
