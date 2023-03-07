{
  pkgs,
  lib,
  ...
}: {

  nix.settings.trusted-users = [
    "@admin"
    "hetzner"
    "builder"
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
}
