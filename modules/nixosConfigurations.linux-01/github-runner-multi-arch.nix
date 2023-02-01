{ config, lib, ... }: {
  services.github-runners = lib.genAttrs
    [
      "multi-arch-01"
      "multi-arch-02"
      "multi-arch-03"
      "multi-arch-04"
      "multi-arch-05"
      "multi-arch-06"
      "multi-arch-07"
      "multi-arch-08"
    ]
    (_: {
      replace = true;
      ephemeral = false;
      extraLabels = [ "multi-arch" ];
      tokenFile = (import ./magicPaths.nix).githubRunnerHraTokenHostPath;
      url = "https://github.com/holochain/holochain";
      extraPackages = config.environment.systemPackages;
    });
}
