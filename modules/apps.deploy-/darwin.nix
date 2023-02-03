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
    }:
      pkgs.writeScript "deploy-${hostName}" ''
        set -Eeuo pipefail
        export PATH="${lib.makeBinPath (with pkgs; [
          nix
        ])}:$PATH"
        set -x

        rsync -r --delete ${self}/ hetzner@${hostName}:/tmp/deploy-flake

        ssh hetzner@${hostName} /nix/var/nix/profiles/default/bin/nix \
          --extra-experimental-features '"flakes nix-command"' \
          build \
            -o /tmp/next-system \
            /tmp/deploy-flake#darwinConfigurations.'"${attrName}"'.system

        ssh hetzner@${hostName} /tmp/next-system/sw/bin/darwin-rebuild \
          switch --flake /tmp/deploy-flake#'"${attrName}"'
      '';

    mkDarwinDeployApp = attrName: config:
      lib.nameValuePair "deploy-${attrName}" {
        type = "app";
        program = builtins.toString (mkDarwinDeploy {
          inherit attrName;
          inherit (config.config) hostName;
        });
      };
  in {
    config.apps = lib.mapAttrs' mkDarwinDeployApp self.darwinConfigurations;
  };
}
