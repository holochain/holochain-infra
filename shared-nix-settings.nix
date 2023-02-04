{
  config,
  pkgs,
  lib,
  ...
}: {
  nix.settings.substituters = ["https://holochain-ci.cachix.org/"];
  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  nix.settings.experimental-features = lib.mkForce ["nix-command" "flakes" "ca-derivations"];
  nix.settings.extra-experimental-features = lib.mkForce ["impure-derivations" "ca-derivations"];
}
