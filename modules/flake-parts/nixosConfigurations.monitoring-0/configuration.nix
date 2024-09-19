{
  config,
  inputs,
  self,
  pkgs,
  ...
}: let
  hostName = "monitoring-0";

  primaryIpv4 = "135.181.110.69";
in {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    self.nixosModules.hardware-hetzner-cloud-cpx

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
  ];

  networking.hostName = hostName; # Define your hostname.

  hostName = primaryIpv4;

  nix.settings.max-jobs = 2;

  nix.settings.substituters = [
    "https://holochain-ci.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-2:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "24.05";
}
