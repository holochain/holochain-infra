{ self, lib, ... }: {
  perSystem = {pkgs, ...}: {
    options.mkLinuxDeploy = lib.mkOption
      {type = lib.types.functionTo lib.types.anything;};

    config.mkLinuxDeploy = {
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
  };
}

