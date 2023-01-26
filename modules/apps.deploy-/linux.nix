# populates apps.{system}.deploy-... for all linux hosts
{ self, lib, ... }: {
  perSystem = {pkgs, ...}: let
    mkLinuxDeploy = {
      attrName,
      hostName,
    }: pkgs.writeScript "deploy-${hostName}" ''
      set -Eeuo pipefail
      export PATH="${lib.makeBinPath (with pkgs; [
        nix
      ])}:$PATH"
      set -x

      rsync -r --delete ${self}/ root@${hostName}:/tmp/deploy-flake

      ssh root@${hostName} nixos-rebuild \
        switch --flake /tmp/deploy-flake#'"${attrName}"'
    '';

    mkLinuxDeployApp = attrName: config: lib.nameValuePair "deploy-${attrName}" {
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

