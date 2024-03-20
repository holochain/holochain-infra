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

    # packages = ...
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
