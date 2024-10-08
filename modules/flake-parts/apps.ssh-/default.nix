# populates apps.{system}.ssh-... for all darwin hosts
{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      prefix = "ssh-";
      mkSsh =
        {
          attrName,
          hostName,
          deployUser,
        }:
        pkgs.writeShellScript "${prefix}${hostName}" ''
          set -Eeo pipefail
          set -x
          ssh ${deployUser}@${hostName} ''${@}
        '';

      mkSshApp =
        attrName: config:
        lib.nameValuePair "${prefix}${attrName}" {
          type = "app";
          program = builtins.toString (mkSsh {
            inherit attrName;
            inherit (config.config) hostName deployUser;
          });
        };
    in
    {
      config.apps =
        let
          configurations = (self.darwinConfigurations // self.nixosConfigurations);

          individual = lib.mapAttrs' mkSshApp configurations;

          distributers = {
            inherit (self.nixosConfigurations) linux-builder-01 buildbot-nix-0;
          };
          mkBuilderPingCommand =
            distributorConfig:
            builtins.concatStringsSep ''&& '' (
              builtins.map (buildMachineAttrs: ''
                (timeout 10s ssh -No StrictHostKeyChecking=accept-new ${buildMachineAttrs.sshUser}@${buildMachineAttrs.hostName} || true) && nix store info --store 'ssh-ng://${buildMachineAttrs.sshUser}@${buildMachineAttrs.hostName}'
              '') distributorConfig.config.nix.buildMachines
            );

          /*
            adds one command for every host that has the nix-build-distributor module imported.
            this command will accept the host keys of all the configured buildMachines and check whether nix can successfully establish a remote connection.
            note that execution takes 10 seconds per buildMachine, because the the key acceptance command hangs indefinitely in the success case.

            run for example: `nix run .\#ssh-buildbot-nix-0-ping-builders
          */
          distributerNixPingBuilders = lib.mapAttrs' (
            attrName: config:
            lib.nameValuePair "${prefix}${attrName}-ping-builders" {
              type = "app";
              program = builtins.toString (
                pkgs.writeShellScript "${prefix}${attrName}-ping-builders" ''
                  exec ${
                    mkSsh {
                      inherit attrName;
                      inherit (config.config) hostName deployUser;
                    }
                  } bash -c "${lib.strings.escapeShellArg (mkBuilderPingCommand config)}"
                ''
              );
            }
          ) distributers;
        in
        individual
        // distributerNixPingBuilders
        // {
          "${prefix}all" = {
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
        };
    };
}
