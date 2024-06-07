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
    ../nixosConfigurations.tfgrid-hpos-base/configuration.nix

    {
      nixpkgs.overlays = builtins.attrValues inputs.holoNixpkgs.outputs.overlays;
    }
    "${inputs.holoNixpkgs}/profiles/logical/hpos"
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

  # TODO: figure out auto-update mechanism
  system.holo-nixpkgs.autoUpgrade.enable = lib.mkForce false;
  services.hpos-led-manager.enable = lib.mkForce false;
  services.netstatsd.enable = lib.mkForce false;
}
