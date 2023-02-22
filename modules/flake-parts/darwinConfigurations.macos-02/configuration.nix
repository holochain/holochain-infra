{
  pkgs,
  lib,
  ...
}: {
  # set options defined by us
  deployUser = "administrator";
  hostName = "hydra-minion-2.holo.host";

  nix.settings.trusted-users = [
    "@admin"
    "administrator"
    "builder"
  ];
  nix.useDaemon = true;
  # runs GC when free space falls below 1GB, and tries to delete up to 5GB.

  nix.settings.max-jobs = 16;

  nix.configureBuildUsers = true;

  services.dnsmasq.enable = true;

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [
  ];
}
