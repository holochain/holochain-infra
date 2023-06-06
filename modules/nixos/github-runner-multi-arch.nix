{
  config,
  lib,
  magicPaths,
  ...
}: let
  githubRunnersCfg = {
    count = 16;
    namePrefix = "multi-arch";
  };

  mkList = prefix: (builtins.genList
    (x: "${prefix}${githubRunnersCfg.namePrefix}-${builtins.toString x}")
    githubRunnersCfg.count);
in {
  services.github-runners =
    lib.genAttrs
    (mkList "")
    (_: {
      replace = true;
      ephemeral = true;
      extraLabels = [githubRunnersCfg.namePrefix];
      tokenFile = magicPaths.githubRunnerHraTokenHostPath;
      url = "https://github.com/holochain/holochain";
      extraPackages = config.environment.systemPackages;
    });

  # TODO where is NodeJS coming from and how can it be updated?
  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-16.20.0"
  ];
}
