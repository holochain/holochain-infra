{
  inputs,
  lib,
  ...
}: {
  flake.nixosModules.holo-users = {
    users.users.root.openssh.authorizedKeys.keyFiles =
      lib.attrValues
      (lib.filterAttrs (name: _: lib.hasPrefix "keys_" name) inputs);
  };
}
