{
  config,
  inputs,
  self,
  pkgs,
  ...
}: let
  hostName = "tfgrid-devnet-vm0";
in {
  imports = [
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-terminfo

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix

    self.nixosModules.zosVmDir
  ];

  networking.hostName = hostName;

  hostName = "TODO";

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [
    "https://holochain-ci.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "23.11";
}
