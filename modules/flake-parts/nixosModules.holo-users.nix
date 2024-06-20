{
  inputs,
  lib,
  ...
}: let
  mkAuthorizedKeys = {...}: {
    keyFiles =
      lib.attrValues
      (lib.filterAttrs (name: _: lib.hasPrefix "keys_" name) inputs);
    keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICHujII5RAwfEXNBYxKhWv2Wx/oHeHUTc8CACZ3M5W3p neonphog@gmail.com"
    ];
  };
in {
  flake.nixosModules.holo-users = {
    users.mutableUsers = false;
    users.users.root.openssh.authorizedKeys = mkAuthorizedKeys {};
    users.users.dev = {
      home = "/home/dev";
      extraGroups = ["wheel"];
      openssh.authorizedKeys = mkAuthorizedKeys {};
      isNormalUser = true;
      createHome = true;
    };
    security.sudo = {
      enable = true;
      execWheelOnly = true;
      extraRules = [
        {
          groups = ["wheel"];
          commands = [
            {
              command = "ALL";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
    };
  };
}
