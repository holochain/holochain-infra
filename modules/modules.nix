{ lib, ... }: {
  options.flake.modules = lib.mkOption {
    type = lib.types.anything;
  };
}
