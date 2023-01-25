# populates apps.{system}.deploy-... for all darwin hosts
{ self, lib, ... }: {
  perSystem = {pkgs, ...}: let
    mkDarwinDeploy = {
      hostName,
      attrName ? "darwin-${hostName}",
    }: pkgs.writeScript "deploy-${hostName}" ''
      set -Eeuo pipefail
      export PATH="${lib.makeBinPath (with pkgs; [
        nix
      ])}:$PATH"
      set -x

      rsync -r --delete ${self}/ hetzner@${hostName}:/tmp/deploy-flake

      ssh hetzner@${hostName} /tmp/next-system/sw/bin/darwin-rebuild \
        switch --flake /tmp/deploy-flake#'"${attrName}"'
    '';

    mkDarwinDeployApp = attrName: config: lib.nameValuePair "deploy-${attrName}" {
      type = "app";
      program = builtins.toString (mkDarwinDeploy {
        inherit attrName;
        hostName = (import "${self}/modules/darwinConfigurations.${attrName}/attrs.nix").hostName;
      });
    };

  in {
    config.apps = lib.mapAttrs' mkDarwinDeployApp self.darwinConfigurations;
  };
}

