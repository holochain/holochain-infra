{
  pkgs,
  lib,
  ...
}: {
  # set options defined by us
  deployUser = "hetzner";
  hostName = "167.235.13.208";

  nix.settings.trusted-users = [
    "hetzner"
  ];
}
