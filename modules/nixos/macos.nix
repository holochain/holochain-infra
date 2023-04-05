{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./shared.nix
    ./shared-nix-settings.nix
  ];

  nix.settings.trusted-users = [
    "@admin"
    config.deployUser
  ];

  nix.useDaemon = lib.mkDefault true;

  nix.configureBuildUsers = lib.mkDefault true;

  services.dnsmasq.enable = lib.mkDefault true;

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = lib.mkDefault true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = lib.mkDefault true;

  programs.zsh.loginShellInit = ''
    echo This machine has nix-darwin based declarative configuration at https://github.com/holochain/holochain-infra.
  '';

  # home-manager settings
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."${config.deployUser}" = {
    home.stateVersion = "22.11";

    # https://github.com/malob/nixpkgs/blob/master/home/default.nix

    # Direnv, load and unload environment variables depending on the current directory.
    # https://direnv.net
    # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;

    # Htop
    # https://rycee.gitlab.io/home-manager/options.html#opt-programs.htop.enable
    programs.htop.enable = true;
    programs.htop.settings.show_program_path = true;
  };
}
