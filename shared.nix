{ config, pkgs, lib, inputs, ... }: {
  # Nix configuration shared between all hosts

  imports = [ ./options.nix ];

  nix.settings.extra-platforms =
    lib.mkIf pkgs.stdenv.isDarwin [ "x86_64-darwin" "aarch64-darwin" ];

  nix.settings.builders-use-substitutes = true;

  nix.settings.max-jobs = lib.mkDefault 4;

  # garbage collection
  nix.settings.min-free = lib.mkDefault (toString (40 * 1024 * 1024 * 1024));
  nix.settings.max-free = lib.mkDefault (toString (60 * 1024 * 1024 * 1024));

  # Enable the automatic gc only to clean up gc-roots.
  # We always want to keep as much as possible in the store.
  # Actual deletion of store paths is done via 'nix.settings.min-free'.
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 10d --max-freed 0";
  } // lib.optionalAttrs pkgs.stdenv.isLinux { dates = "daily"; }
  // lib.optionalAttrs pkgs.stdenv.isDarwin { interval.Hour = 0; };

  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = (with pkgs; [
    nix
    gnugrep
    gnutar
    gzip
    coreutils
    libressl.nc
    procps
    xz
    zstd
    openssh
    tree
    tmux
    upterm
    gawk
    gitFull
    vim
  ]) ++ [
    inputs.cachix.packages.${pkgs.stdenv.system}.cachix
  ];
}
