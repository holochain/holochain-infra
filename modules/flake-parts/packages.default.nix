{
  # System independent arguments.
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    pkgs,
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    packages = {
      reverse-proxy-nix-cache = pkgs.writeShellScriptBin "reverse-proxy-nix-cache" ''
        sudo ${pkgs.caddy}/bin/caddy reverse-proxy --from :80 --to :5000
      '';
    };
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
