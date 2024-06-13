{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}: let
  hostName = "tfgrid-hpos-base";
in {
  imports = [
    ../nixosConfigurations.tfgrid-base/configuration.nix

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.nomad-client

    "${inputs.holoNixpkgs}/profiles/logical/binary-cache.nix"
  ];

  system.stateVersion = lib.mkForce "23.11";

  sops.age.keyFile = "/etc/age.key";

  environment.systemPackages = [
    pkgs.man
  ];

  holochain-infra.nomad-client = {
    enable = false;
    machineType = "zos-vm";
  };

  networking.hostName = hostName;
}
