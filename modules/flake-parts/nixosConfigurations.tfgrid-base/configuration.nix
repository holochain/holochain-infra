{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}: let
  hostName = "tfgrid-base";
in {
  imports = [
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-terminfo

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix

    self.nixosModules.zosVmDir
  ];

  # srvos' server module sets this with lib.mkDefault (1000) so go slightly higher in priority (lower in number)
  networking.hostName = lib.mkOverride 999 hostName;

  nix.settings.substituters = [
    "https://holochain-ci.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "23.11";
}
