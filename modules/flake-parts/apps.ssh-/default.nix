# populates apps.{system}.deploy-... for all darwin hosts
{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    mkSsh = {
      attrName,
      hostName,
      deployUser,
    }:
      pkgs.writeScript "deploy-${hostName}" ''
        set -Eeuo pipefail
        set -x
        ssh ${deployUser}@${hostName}
      '';

    mkSshApp = attrName: config:
      lib.nameValuePair "ssh-${attrName}" {
        type = "app";
        program = builtins.toString (mkSsh {
          inherit attrName;
          inherit (config.config) hostName deployUser;
        });
      };
  in {
    config.apps =
      lib.mapAttrs' mkSshApp
      (self.darwinConfigurations // self.nixosConfigurations);
  };
}
