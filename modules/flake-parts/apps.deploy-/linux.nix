# populates apps.{system}.deploy-... for all linux hosts
{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mkLinuxDeploy =
        { attrName, hostName }:
        pkgs.writeShellScript "deploy-${hostName}" ''
          set -Eeo pipefail
          export PATH="${
            lib.makeBinPath (
              with pkgs;
              [
                git
                coreutils
              ]
            )
          }:$PATH"
          set -x

          ssh root@${hostName} nixos-rebuild \
            -j4 \
            "''${1:-switch}" --refresh --flake github:holochain/holochain-infra/deploy/${attrName}#'"${attrName}"'
        '';

      mkLinuxDeployApp =
        attrName: config:
        lib.nameValuePair "deploy-${attrName}" {
          type = "app";
          program = builtins.toString (mkLinuxDeploy {
            inherit attrName;
            inherit (config.config) hostName;
          });
        };

      mkLinuxDeployDirect =
        { attrName, hostName }:
        pkgs.writeShellScript "deploy-direct-${hostName}" ''
          set -Eeo pipefail
          export PATH="${
            lib.makeBinPath (
              with pkgs;
              [
                nix
                git
                coreutils
              ]
            )
          }:$PATH"
          set -uxeE -o pipefail

          closure_path=$(nix build --print-out-paths --refresh github:holochain/holochain-infra/deploy/${attrName}#nixosConfigurations.${attrName}.config.system.build.toplevel)

          nix-copy-closure --to root@${hostName} $closure_path

          ssh root@${hostName} "$closure_path/bin/switch-to-configuration ''${1:-switch}"
        '';

      mkLinuxDeployDirectApp =
        attrName: config:
        lib.nameValuePair "deploy-direct-${attrName}" {
          type = "app";
          program = builtins.toString (mkLinuxDeployDirect {
            inherit attrName;
            inherit (config.config) hostName;
          });
        };
    in
    {
      config.apps =
        (lib.mapAttrs' mkLinuxDeployApp self.nixosConfigurations)
        // (lib.mapAttrs' mkLinuxDeployDirectApp self.nixosConfigurations)
        // { };
    };
}
