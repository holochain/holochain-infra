# populates apps.{system}.deploy-... for all linux hosts
{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    mkLinuxDeploy = {
      attrName,
      hostName,
    }:
      pkgs.writeShellScript "deploy-${hostName}" ''
        set -Eeo pipefail
        export PATH="${lib.makeBinPath (with pkgs; [
          git
          coreutils
        ])}:$PATH"
        set -x

        ssh root@${hostName} nixos-rebuild \
          -j4 \
          "''${1:-switch}" --refresh --flake github:holochain/holochain-infra/deploy/${attrName}#'"${attrName}"'
      '';

    mkLinuxDeployApp = attrName: config:
      lib.nameValuePair "deploy-${attrName}" {
        type = "app";
        program = builtins.toString (mkLinuxDeploy {
          inherit attrName;
          inherit (config.config) hostName;
        });
      };
  in {
    config.apps = lib.mapAttrs' mkLinuxDeployApp self.nixosConfigurations;
  };
}
