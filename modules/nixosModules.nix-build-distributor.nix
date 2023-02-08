{...}: {
  flake.nixosModules.nix-build-distributor = {
    config,
    lib,
    ...
  }: {
    nix.settings.max-jobs = lib.mkDefault 0;

    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "167.235.13.208";
        sshUser = "builder";
        protocol = "ssh-ng";
        system = "aarch64-darwin";
        maxJobs = 4;
        supportedFeatures = config.nix.settings.experimental-features;
      }
      {
        hostName = "167.235.13.208";
        sshUser = "builder";
        protocol = "ssh-ng";
        system = "x86_64-darwin";
        maxJobs = 4;
        supportedFeatures = config.nix.settings.experimental-features;
      }

      # currently not required as this machine runs the distributor
      # {
      #   hostName = "95.217.193.35";
      #   sshUser = "builder";
      #   protocol = "ssh-ng";
      #   system = "x86_64-linux";
      #   maxJobs = 32;
      #   supportedFeatures = config.nix.settings.experimental-features;
      # }
    ];
  };
}