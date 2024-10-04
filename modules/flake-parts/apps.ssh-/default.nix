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
        in
        individual
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
