{ pkgs, lib, ... }:
{
  # Nix configuration ------------------------------------------------------------------------------

  nix.binaryCaches = [
    "https://cache.nixos.org/"
    "https://holochain-ci.cachix.org/"
  ];
  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];
  nix.trustedUsers = [
    "@admin"
  ];
  nix.useDaemon = true;
  # runs GC when free space falls below 1GB, and tries to delete up to 5GB.

  users.nix.configureBuildUsers = true;

  services.dnsmasq.enable = true;

  services.github-runners = let
    mkRunner = system: {
      inherit system;
      replace = true;
      ephemeral = false;
      tokenFile = "/Users/hetzner/hra2.token";
      url = "https://github.com/holochain/holochain";
      extraEnvironment.NIX_USER_CONF_FILES = toString (
        pkgs.writeText "nix.conf" ''
          extra-experimental-features = flakes nix-command
          extra-trusted-public-keys = holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8=
          extra-substituters = holochain-ci.cachix.org
          max-jobs = 8
        ''
      );
    };
  in {
    aarch64-darwin-01 = mkRunner "aarch64-darwin";
    aarch64-darwin-02 = mkRunner "aarch64-darwin";
    x86_64-darwin-01 = mkRunner "x86_64-darwin";
    x86_64-darwin-02 = mkRunner "x86_64-darwin";
  };

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    min-free = ${toString (1 * 1024 * 1024 * 1024)}
    max-free = ${toString (5 * 1024 * 1024 * 1024)}
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [
    gnutar
    gzip
    coreutils
    libressl.nc
    procps
    cachix
    xz
    zstd
    openssh
    tree
    tmux
    upterm
    gawk
    gitFull
    vim
  ];
}
