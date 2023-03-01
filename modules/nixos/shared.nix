{
  config,
  pkgs,
  lib,
  ...
}: {
  # Nix configuration shared between all hosts

  imports = [./holo-deploy.nix];

  nix.settings.extra-platforms =
    lib.mkIf pkgs.stdenv.isDarwin ["x86_64-darwin" "aarch64-darwin"];

  nix.settings.builders-use-substitutes = true;

  nix.settings.max-jobs = lib.mkDefault "auto";
  nix.settings.keep-outputs = true; # Nice for developers
  nix.settings.keep-derivations = true; # Idem

  # garbage collection
  nix.settings.min-free = lib.mkOptionDefault (toString (1 * 1024 * 1024 * 1024));
  nix.settings.max-free = lib.mkOptionDefault (toString (11 * 1024 * 1024 * 1024));

  nix.settings.system-features = ["recursive-nix"];

  # Enable the automatic gc only to clean up gc-roots.
  # We always want to keep as much as possible in the store.
  # Actual deletion of store paths is done via 'nix.settings.min-free'.
  nix.gc =
    {
      automatic = true;
      options = lib.mkForce ''--max-freed "$((48* 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))"'';
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux (lib.mkForce {
      dates = "*:5,15,25,35,45,55";
      randomizedDelaySec = "60";
    })
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # frequencies higher than 1h are currently not possible in nix-darwin.
      # It could be possible to patch nix-darwin to support a list of dates,
      # launchd might support this according to https://developer.apple.com/forums/thread/22946
      interval.Minute = 17;
    };

  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages =
    (with pkgs; [
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
      cachix
    ])
    ++ [
    ];
}
