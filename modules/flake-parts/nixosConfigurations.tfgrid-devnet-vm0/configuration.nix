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
    ../nixosConfigurations.tfgrid-base/configuration.nix

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.nomad-client
  ];

  sops.age.keyFile = "/etc/age.key";

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
