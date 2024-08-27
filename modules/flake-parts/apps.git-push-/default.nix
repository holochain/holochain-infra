{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    mkGitPush = {
      attrName,
      hostName,
    }:
      pkgs.writeShellScript "git-push-${hostName}" ''
        set -Eeou pipefail
        export PATH="${lib.makeBinPath (with pkgs; [
          git
        ])}:$PATH"
        set -x

        remote=''${1:-origin}
        local_branch=''${2:-HEAD}
        shift || :
        shift || :

        git push $remote $local_branch:refs/heads/deploy/${attrName} ''${@}
      '';

    mkGitPushApp = attrName: config:
      lib.nameValuePair "git-push-${attrName}" {
        type = "app";
        program = builtins.toString (mkGitPush {
          inherit attrName;
          inherit (config.config) hostName;
        });
      };

    mkNvd= let
      commonNixArgs = "nix build --print-out-paths --no-link";
    in {
      attrName,
      config,
    }:
      pkgs.writeShellScript "build-and-diff-${config.hostName}" ''
        set -Eeou pipefail

        export PATH="${lib.makeBinPath ([
          pkgs.nvd
        ])}:$PATH"

        set -x

        remote=''${1:-origin}
        local_branch=''${2:-HEAD}
        shift || :
        shift || :

        currentSystem=$(${commonNixArgs} github:holochain/holochain-infra/deploy/${attrName}#nixosConfigurations.${attrName}.config.system.build.toplevel)
        nextSystem=$(${commonNixArgs} .#nixosConfigurations.${attrName}.config.system.build.toplevel)

        nvd diff "$currentSystem" "$nextSystem"
      '';

    mkNvdApp = attrName: config:
      lib.nameValuePair "build-and-diff-${attrName}" {
        type = "app";
        program = builtins.toString (mkNvd {
          inherit attrName;
          inherit (config) config;
        });
      };

  in {
    config.apps = (lib.mapAttrs' mkGitPushApp (self.darwinConfigurations // self.nixosConfigurations)) //
      (lib.mapAttrs' mkNvdApp (self.darwinConfigurations // self.nixosConfigurations))
    ;
  };
}
