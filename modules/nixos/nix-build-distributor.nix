{
  config,
  lib,
  ...
}: {
  nix.settings.max-jobs = lib.mkDefault 0;

  nix.distributedBuilds = true;
  nix.buildMachines = [
    # macos-01
    # - m1 cpu
    # - system integrity protection disabled
    {
      hostName = "167.235.13.208";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "x86_64-darwin";
      # has a broken nix installation
      maxJobs = 0;
      speedFactor = 1;
      supportedFeatures = config.nix.settings.experimental-features;
    }

    # macos-02
    # - intel CPU
    {
      hostName = "hydra-minion-2.holo.host";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "x86_64-darwin";
      speedFactor = 2;
      maxJobs = 4;
      supportedFeatures = config.nix.settings.experimental-features;
    }

    # macos-03
    # - m1 cpu
    # - system integrity protection enabled
    {
      hostName = "142.132.140.224";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "aarch64-darwin";
      maxJobs = 3;
      speedFactor = 2;
      supportedFeatures = config.nix.settings.experimental-features;
    }

    # macos-04
    # - m1 cpu
    # - system integrity protection disabled
    {
      hostName = "167.235.38.111";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "aarch64-darwin";
      # had a factory reset, still needs setting up
      maxJobs = 0;
      # maxJobs = 3;
      speedFactor = 2;
      supportedFeatures = config.nix.settings.experimental-features;
    }

    # macos-05
    # - m2 cpu
    # - system integrity protection enabled?
    {
      hostName = "hydra-minion-3.holo.host";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "aarch64-darwin";
      maxJobs = 6;
      speedFactor = 3;
      supportedFeatures = config.nix.settings.experimental-features;
    }

    # macos-06
    # - intel CPU
    {
      hostName = "208.52.154.135";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "x86_64-darwin";
      speedFactor = 2;
      maxJobs = 6;
      supportedFeatures = config.nix.settings.experimental-features;
    }

    # {
    #   hostName = "95.217.193.35";
    #   sshUser = "builder";
    #   protocol = "ssh-ng";
    #   system = "x86_64-linux";
    #   maxJobs = 32;
    #   supportedFeatures = config.nix.settings.experimental-features;
    # }
  ];
}
