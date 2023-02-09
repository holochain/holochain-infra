{lib, config, ...}: {
  options.flake.modules = lib.mkOption {
    type = lib.types.anything;
  };

  config.flake.modules.darwin =
    lib.mapAttrs
    (_: m: "${../darwin}/${m}")
    (builtins.readDir ../darwin);

  config.flake.modules.nixos =
    lib.mapAttrs
    (_: m: "${../nixos}/${m}")
    (builtins.readDir ../nixos);

  config.flake.modules.flake-parts =
    lib.mapAttrs
    (_: m: "${../flake-parts}/${m}")
    (builtins.readDir ../flake-parts);

  # comapt to legacy schema
  config.flake.nixosModules = config.flake.modules.nixos;
  config.flake.darwinModules = config.flake.modules.darwin;
}
