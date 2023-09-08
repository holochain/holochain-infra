{
  self,
  config,
  lib,
  magicPaths,
  pkgs,
  ...
}: let
  githubRunnersCfg = {
    count = 16;
    namePrefix = "multi-arch";
  };

  nixpkgsGithubActionRunners' = pkgs.callPackage self.inputs.nixpkgsGithubActionRunners {};

  package = nixpkgsGithubActionRunners'.github-runner;

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
      inherit package;
      extraLabels = [githubRunnersCfg.namePrefix];
      tokenFile = config.sops.secrets.github-runners-token.path;
      url = "https://github.com/holochain/holochain";
      extraPackages = config.environment.systemPackages;
    });

  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-16.20.2"
  ];
}
