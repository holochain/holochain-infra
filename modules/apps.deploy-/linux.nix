# populates apps.{system}.deploy-... for all linux hosts
{ self, lib, ... }: {
  perSystem = {pkgs, ...}: let
    mkLinuxDeploy = {
      hostName,
      attrName ? "darwin-${hostName}",
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
        hostName = (import "${self}/modules/nixosConfigurations.${attrName}/attrs.nix").hostName;
      });
    };
  in {
    config.apps = lib.mapAttrs' mkLinuxDeployApp self.nixosConfigurations;
  };
}

