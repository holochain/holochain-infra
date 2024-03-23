{
  # System independent arguments.
  self,
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    pkgs,
    self',
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    packages = {
      reverse-proxy-nix-cache = pkgs.writeShellScriptBin "reverse-proxy-nix-cache" ''
        sudo ${pkgs.caddy}/bin/caddy reverse-proxy --from :80 --to :5000
      '';

      turn-readiness-check = pkgs.writeShellApplication {
        name = "turn-readiness-check";
        runtimeInputs = [
          self'.packages.tx5
        ];
        text =
          ''
            set -e
          ''
          + builtins.concatStringsSep "\n" (builtins.map (
              name: ''
                echo "### checking ${name}... ###"
                set -x
                turn-stress ${name}.infra.holochain.org 443 test test
                turn_doctor wss://${self.nixosConfigurations.${name}.config.services.tx5-signal-server.url}
                set +x
                echo "### checking ${name}: success ###"
              ''
            )
            (builtins.filter (name: (builtins.match "turn-[0-9]+" name) != null) (builtins.attrNames self.nixosConfigurations)))
          + ''
            echo success
          '';
      };
    };
  };

  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
