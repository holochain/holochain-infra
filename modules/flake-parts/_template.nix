{
  # System independent arguments.
  ...
}:
{
  perSystem =
    {
      # Arguments specific to the `perSystem` context.
      ...
    }:
    {
      # system specific outputs like, apps, checks, packages

      # packages = ...
    };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
