{
  self,
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  nixpkgsGithubActionRunners' = pkgs.callPackage self.inputs.nixpkgsGithubActionRunners {};

  mkList =
    builtins.genList
    (x: "${cfg.namePrefix}-${builtins.toString (x + cfg.countOffset)}")
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

    url = lib.mkOption {
      description = "url";
      default = "https://github.com/holochain/holochain";
      type = lib.types.str;
    };

    namePrefix = lib.mkOption {
      description = "prefix for the runner names";
      default = "multi-arch";
      type = lib.types.str;
    };

    tokenFile =
      options.services.github-runner.tokenFile
      // {
        default = config.sops.secrets.github-runners-token.path;
      };

    package = lib.mkOption {
      default = nixpkgsGithubActionRunners'.github-runner;
    };
  };

  config = lib.mkIf cfg.enable {
    services.github-runners =
      lib.genAttrs mkList
      (_: {
        replace = true;
        ephemeral = true;
        extraLabels = [cfg.namePrefix config.networking.hostName];
        tokenFile = cfg.tokenFile;
        inherit (cfg) url package;

        extraPackages = config.environment.systemPackages;
      });
  };
}
