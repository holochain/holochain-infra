{config, lib, ...}: {
  services.github-runners = lib.genAttrs
    [
      "multi-arch-01"
      "multi-arch-02"
    ]
    (_: {
      replace = true;
      ephemeral = false;
      extraLabels = ["multi-arch"];
      tokenFile = (import ./magicPaths.nix).githubRunnerHraTokenHostPath;
      url = "https://github.com/holochain/holochain";
      extraPackages = config.environment.systemPackages;
    });
}
