{
  self,
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
  flake.nixosModules.holo-users = {config, ...}: {
    users.mutableUsers = false;
    users.users.root.openssh.authorizedKeys = mkAuthorizedKeys {};

    # a generic dev user that can be used to have per-host home-manager environments for it.
    # this adds no risk since all potential users already have access to the root account via their SSH credentials.
    users.users.dev = {
      home = "/home/dev";
      extraGroups = ["wheel"];
      openssh.authorizedKeys = mkAuthorizedKeys {};
      isNormalUser = true;
      createHome = true;
    };

    sops.secrets.dev-age-key = {
      sopsFile = self + "/secrets/dev/secrets.yaml";
      owner = "dev";
    };
    home-manager = {
      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
      ];
      users.dev = {
        home.environment.SOPS_AGE_KEY_FILE = config.sops.secrets.dev-age-key.path;
        sops = {
          age.keyFile = config.sops.secrets.dev-age-key.path;
          defaultSopsFile = self + "/secrets/dev/secrets.yaml";
        };
      };
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
