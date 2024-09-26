{
  pkgs,
  lib,
  ...
}: {
  nix.settings.substituters = [
    "https://holochain-ci.cachix.org/"
    "https://holochain-ci-internal.cachix.org/"
  ];
  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
    "holochain-ci-internal.cachix.org-1:QvVsSrTiearCjrLTVtNtJOdQCDTseXh7UXUuSMx46NE="
  ];

  nix.settings.experimental-features = lib.mkForce [
    "nix-command"
    "flakes"
  ];
  nix.settings.sandbox =
    if pkgs.stdenv.isLinux
    then "relaxed"
    else false;
}
