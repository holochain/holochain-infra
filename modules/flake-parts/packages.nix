{
  # System independent arguments.
  self,
  lib,
  inputs,
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    config,
    self',
    inputs',
    pkgs,
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    packages = {
      reverse-proxy-nix-cache = let

      in pkgs.writeShellScriptBin "reverse-proxy-nix-cache" ''
        sudo ${pkgs.caddy}/bin/caddy reverse-proxy --from :80 --to :5000
      '';

    };
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
