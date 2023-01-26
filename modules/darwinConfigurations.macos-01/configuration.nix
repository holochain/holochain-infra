{ pkgs, lib, ... }:
{

  # set options defined by us
  deployUser = "hetzner";
  hostName = "167.235.13.208";

  nix.settings.trusted-users = [
    "@admin"
    "github-runner"
    "hetzner"
    "builder"
  ];
  nix.useDaemon = true;
  # runs GC when free space falls below 1GB, and tries to delete up to 5GB.

  nix.settings.max-jobs = 8;

  nix.configureBuildUsers = true;

  services.dnsmasq.enable = true;

  # services.github-runners-tart = let
  #   runnerConf = {
  #     replace = true;
  #     ephemeral = true;
  #     tokenFile = "/Users/hetzner/hra2.token";
  #     url = "https://github.com/holochain/holochain";
  #   };
  # in {
  #   aarch64-darwin-tart-01 = runnerConf;
  #   aarch64-darwin-tart-02 = runnerConf;
  # };

  services.github-runners = let
    runnerConf = {
      replace = true;
      ephemeral = true;
      tokenFile = "/Users/hetzner/hra2.token";
      url = "https://github.com/holochain/holochain";
    };
  in {
    aarch64-darwin-01 = runnerConf;
    aarch64-darwin-02 = runnerConf;
  };

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
