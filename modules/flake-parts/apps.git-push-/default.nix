{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      prefix = "git-push-";
      mkGitPush =
        { attrName, hostName }:
        pkgs.writeShellScript "${prefix}${hostName}" ''
          set -Eeou pipefail
          export PATH="${lib.makeBinPath (with pkgs; [ git ])}:$PATH"
          set -x

          remote=''${1:-origin}
          local_branch=''${2:-HEAD}
          shift || :
          shift || :

          git push $remote $local_branch:refs/heads/deploy/${attrName} ''${@}
        '';

      mkGitPushApp =
        attrName: config:
        lib.nameValuePair "${prefix}${attrName}" {
          type = "app";
          program = builtins.toString (mkGitPush {
            inherit attrName;
            inherit (config.config) hostName;
          });
        };
      configurations = self.darwinConfigurations // self.nixosConfigurations;
      individual = lib.mapAttrs' mkGitPushApp configurations;
    in
    {
      config.apps = individual // {
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
