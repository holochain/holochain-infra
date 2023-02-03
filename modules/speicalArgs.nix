{ self, lib, inputs, ... }: {
  flake = {
    options.specialArgs = lib.mkOption {type = lib.types.attrs;};
    config.specialArgs = {
      inherit inputs self;
    };
  };
}
