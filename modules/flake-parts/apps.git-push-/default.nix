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
  in {
    config.apps = lib.mapAttrs' mkGitPushApp (self.darwinConfigurations // self.nixosConfigurations);
  };
}
