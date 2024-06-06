{
  self,
  config,
  lib,
  pkgs,
  ...
}: let
  nixpkgsGithubActionRunners' = pkgs.callPackage self.inputs.nixpkgsGithubActionRunners {};

  package = nixpkgsGithubActionRunners'.github-runner;

  mkList = builtins.genList
    (x: "${cfg.namePrefix}-${builtins.toString (x+cfg.countOffset)}")
    cfg.count;

    cfg = config.services.github-runner-multi-arch;
in {
  options.services.github-runner-multi-arch = {
    enable = lib.mkEnableOption "self-hosted multi-arch github runner on holochain/holochain";
    count = lib.mkOption {
      description = "how many runners are spawned";
      default = 16;
      type = lib.types.int;
    };

    countOffset = lib.mkOption {
      description = "offset to the count for numbering the runners";
      default = 0;
      type = lib.types.int;
    };

    namePrefix= lib.mkOption {
      description = "prefix for the runner names";
      default = "multi-arch";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    services.github-runners =
      lib.genAttrs mkList
      (_: {
        replace = true;
        ephemeral = true;
        inherit package;
        extraLabels = [cfg.namePrefix];
        tokenFile = config.sops.secrets.github-runners-token.path;
        url = "https://github.com/holochain/holochain";
        extraPackages = config.environment.systemPackages;
      });

    nixpkgs.config.permittedInsecurePackages = [
      "nodejs-16.20.2"
    ];
  };
}
