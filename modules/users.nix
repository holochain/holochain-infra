{ inputs, lib, ... }: {
  options.sshKeysAll = lib.mkOption {type = lib.types.listOf lib.types.path;};
  config.sshKeysAll =
    lib.attrValues
    (lib.filterAttrs (name: _: lib.hasPrefix "key_" name) inputs);
}
