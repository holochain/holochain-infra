{
  inputs,
  lib,
  ...
}: {
  flake.nixosModules.holo-users = {
    users.users.root.openssh.authorizedKeys = {
      keyFiles =
        lib.attrValues
        (lib.filterAttrs (name: _: lib.hasPrefix "keys_" name) inputs);
      keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICHujII5RAwfEXNBYxKhWv2Wx/oHeHUTc8CACZ3M5W3p neonphog@gmail.com"
      ];
    };
  };
}
