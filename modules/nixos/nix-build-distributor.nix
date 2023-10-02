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
      maxJobs = 4;
      supportedFeatures = config.nix.settings.experimental-features;
    }
    # macos-02
    # - intel CPU
    {
      hostName = "hydra-minion-2.holo.host";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "x86_64-darwin";
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
      maxJobs = 4;
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
      maxJobs = 4;
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
