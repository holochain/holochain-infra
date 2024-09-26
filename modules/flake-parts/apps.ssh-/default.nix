# populates apps.{system}.deploy-... for all darwin hosts
{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mkSsh =
        {
          attrName,
          hostName,
          deployUser,
        }:
        pkgs.writeShellScript "ssh-${hostName}" ''
          set -Eeo pipefail
          set -x
          ssh ${deployUser}@${hostName} ''${@}
        '';

      mkSshApp =
        attrName: config:
        lib.nameValuePair "ssh-${attrName}" {
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
          individual = lib.mapAttrs' mkSshApp (self.darwinConfigurations // self.nixosConfigurations);
        in
        individual
        // {
          ssh-all = {
            type = "app";
            program = builtins.toString (
              pkgs.writeShellScript "ssh-all" (
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
