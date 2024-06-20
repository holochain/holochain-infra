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
  };

  flake.nixosModules.holo-users-interactive = {config, ...}: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];

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
      useGlobalPkgs = true;
      useUserPackages = true;

      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
      ];
      users.dev = {pkgs, ...}: {
        # Home Manager needs a bit of information about you and the
        # paths it should manage.
        home.username = "dev";
        home.homeDirectory = "/home/dev";

        home.packages = [
          pkgs.coreutils
          pkgs.neovim
        ];

        programs.bash.enable = true;
        programs.bash.sessionVariables.SOPS_AGE_KEY_FILE = config.sops.secrets.dev-age-key.path;

        programs.direnv.enable = true;
        # TODO: enable this once home-manager is bumped to >= release-24.05
        # programs.nix-direnv.enable = true;

        # This value determines the Home Manager release that your
        # configuration is compatible with. This helps avoid breakage
        # when a new Home Manager release introduces backwards
        # incompatible changes.
        #
        # You can update Home Manager without changing this value. See
        # the Home Manager release notes for a list of state version
        # changes in each release.
        home.stateVersion = "23.11";

        # Let Home Manager install and manage itself.
        programs.home-manager.enable = true;

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
