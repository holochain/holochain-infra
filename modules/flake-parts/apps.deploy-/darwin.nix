# populates apps.{system}.deploy-... for all darwin hosts
{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mkDarwinDeploy =
        {
          attrName,
          hostName,
          deployUser,
        }:
        pkgs.writeShellScript "deploy-${hostName}" ''
          set -Eeo pipefail
          export PATH="${
            lib.makeBinPath (
              with pkgs;
              [
                nix
                rsync
              ]
            )
          }:$PATH"
          set -x

          flake_base=github:holochain/holochain-infra/deploy/${attrName}

          ssh ${deployUser}@${hostName} /nix/var/nix/profiles/default/bin/nix \
            --extra-experimental-features '"flakes nix-command"' \
            build --refresh \
              -o /private/tmp/next-system \
              $flake_base#darwinConfigurations.'"${attrName}"'.system

          ssh ${deployUser}@${hostName} /private/tmp/next-system/sw/bin/darwin-rebuild \
            -j4 --refresh \
            "''${1:-switch}" --flake $flake_base#'"${attrName}"'
        '';

      mkDarwinDeployApp =
        attrName: config:
        lib.nameValuePair "deploy-${attrName}" {
          type = "app";
          program = builtins.toString (mkDarwinDeploy {
            inherit attrName;
            inherit (config.config) hostName deployUser;
          });
        };

      individual = lib.mapAttrs' mkDarwinDeployApp self.darwinConfigurations;
    in
    {
      config.apps = individual // {
        deploy-darwin-all = {
          type = "app";
          program = builtins.toString (
            pkgs.writeShellScript "deploy-all" (
              builtins.concatStringsSep "\n" (
                lib.mapAttrsToList (name: value: ''
                  echo \# ${name}: running ${value.program} ''${@}
                  ${value.program} ''${@}
                '') individual
              )
            )
          );
        };

      };
    };
}
