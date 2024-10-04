# populates apps.{system}.deploy-... for all linux hosts
{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      prefix = "deploy-";
      prefixDirect = "deploy-direct";
      mkLinuxDeploy =
        { attrName, hostName }:
        pkgs.writeShellScript "${prefix}${hostName}" ''
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
        lib.nameValuePair "${prefix}${attrName}" {
          type = "app";
          program = builtins.toString (mkLinuxDeploy {
            inherit attrName;
            inherit (config.config) hostName;
          });
        };

      mkLinuxDeployDirect =
        { attrName, hostName }:
        pkgs.writeShellScript "${prefixDirect}${hostName}" ''
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
        lib.nameValuePair "${prefixDirect}${attrName}" {
          type = "app";
          program = builtins.toString (mkLinuxDeployDirect {
            inherit attrName;
            inherit (config.config) hostName;
          });
        };

      configurations = self.nixosConfigurations;
      individual = lib.mapAttrs' mkLinuxDeployApp configurations;
      individualDirect = lib.mapAttrs' mkLinuxDeployDirectApp configurations;
    in
    {
      config.apps =
        individual
        // individualDirect
        // {
          "${prefix}linux-all" = {
            type = "app";
            program = builtins.toString (
              pkgs.writeShellScript "${prefix}all" (
                builtins.concatStringsSep "\n" (
                  lib.mapAttrsToList
                    (name: value: ''
                      echo \# ${name}: running ${value.program} ''${@}
                      ${value.program} ''${@}
                    '')
                    (
                      lib.filterAttrs (
                        name: _: !configurations.${builtins.replaceStrings [ prefix ] [ "" ] name}.config.deploySkipAll
                      ) individual
                    )
                )
              )
            );
          };
          "${prefixDirect}linux-all" = {
            type = "app";
            program = builtins.toString (
              pkgs.writeShellScript "${prefixDirect}-all" (
                builtins.concatStringsSep "\n" (
                  lib.mapAttrsToList
                    (name: value: ''
                      echo \# ${name}: running ${value.program} ''${@}
                      ${value.program} ''${@}
                    '')
                    (
                      lib.filterAttrs (
                        name: _:
                        !configurations.${builtins.replaceStrings [ prefixDirect ] [ "" ] name}.config.deploySkipAll
                      ) individualDirect
                    )
                )
              )
            );
          };
        };
    };
}
