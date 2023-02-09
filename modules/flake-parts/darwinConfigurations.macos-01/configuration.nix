{
  pkgs,
  lib,
  ...
}: {
  # set options defined by us
  deployUser = "hetzner";
  hostName = "167.235.13.208";

  nixpkgs.overlays = let
    nixOverlay = curr: prev: {
      nix =
        prev.nix.overrideAttrs
        (old: {
          patches =
            (old.patches or [])
            ++ [
              ./0001-fix-daemon.cc-Lock-gc.lock-on-nix-daemon-stdio.patch
            ];
        });
    };
  in [nixOverlay];

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
