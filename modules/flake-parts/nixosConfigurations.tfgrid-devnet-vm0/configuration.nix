{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
let
  hostName = "tfgrid-devnet-vm0";
in
{
  imports = [
    ../nixosConfigurations.tfgrid-base/configuration.nix

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.nomad-client
  ];

  system.stateVersion = lib.mkForce "23.11";

  sops.age.keyFile = "/etc/age.key";

  nix.settings.max-jobs = 8;

  environment.systemPackages = [
    pkgs.iperf3
    pkgs.man
  ];

  holochain-infra.nomad-client = {
    enable = true;
    machineType = "zos-vm";
  };

  networking.hostName = hostName;
}
