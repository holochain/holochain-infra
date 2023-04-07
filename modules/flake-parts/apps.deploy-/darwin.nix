# populates apps.{system}.deploy-... for all darwin hosts
{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    mkDarwinDeploy = {
      attrName,
      hostName,
      deployUser,
    }:
      pkgs.writeShellScript "deploy-${hostName}" ''
        set -Eeo pipefail
        export PATH="${lib.makeBinPath (with pkgs; [
          nix
          rsync
        ])}:$PATH"
        set -x

        rsync -r --delete ${self}/ ${deployUser}@${hostName}:/tmp/deploy-flake

        ssh ${deployUser}@${hostName} /nix/var/nix/profiles/default/bin/nix \
          --extra-experimental-features '"flakes nix-command"' \
          build \
            -o /tmp/next-system \
            /tmp/deploy-flake#darwinConfigurations.'"${attrName}"'.system

        ssh ${deployUser}@${hostName} /tmp/next-system/sw/bin/darwin-rebuild \
          -j4 \
          "''${1:-switch}" --flake /tmp/deploy-flake#'"${attrName}"'
      '';

    mkDarwinDeployApp = attrName: config:
      lib.nameValuePair "deploy-${attrName}" {
        type = "app";
        program = builtins.toString (mkDarwinDeploy {
          inherit attrName;
          inherit (config.config) hostName deployUser;
        });
      };
  in {
    config.apps = lib.mapAttrs' mkDarwinDeployApp self.darwinConfigurations;
  };
}
