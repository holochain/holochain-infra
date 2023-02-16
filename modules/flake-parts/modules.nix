{lib, config, ...}: let

  mapModules = kind:
    lib.mapAttrs'
    (fn: _:
      lib.nameValuePair
      (lib.removeSuffix ".nix" fn)
      "${../.}/${kind}/${fn}")
    (builtins.readDir ("${../.}/${kind}"));

in {

  options.flake.modules = lib.mkOption {
    type = lib.types.anything;
  };

  # generates flake outputs: `modules.<kind>.<module-name>`
  config.flake.modules.nixos = mapModules "nixos";
  config.flake.modules.flake-parts = mapModules "flake-parts";

  # comapt to legacy schema: `nixosModules` / `darwinModules`
  config.flake.nixosModules = config.flake.modules.nixos;
}
