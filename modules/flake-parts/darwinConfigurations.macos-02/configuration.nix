{
  pkgs,
  lib,
  ...
}: {
  # set options defined by us
  deployUser = "administrator";
  hostName = "hydra-minion-2.holo.host";

  nix.settings.trusted-users = [
    "administrator"
  ];
}
