{ self, lib, ... }: {
  perSystem = {pkgs, ...}: {
    options.mkDarwinDeploy = lib.mkOption
      {type = lib.types.functionTo lib.types.anything;};

    config.mkDarwinDeploy = {
      hostName,
      attrName ? "darwin-${hostName}",
    }: pkgs.writeScript "deploy-${hostName}" ''
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
  };
}

