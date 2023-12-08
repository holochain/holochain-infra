{ config, lib, pkgs, ...}: let
  cleanup0sizeDrvs = (import ./shared-linux.nix { inherit config pkgs; }).systemd.services.nix-gc.preStart;
in {
  launchd.daemons.nix-gc.command = lib.mkForce (pkgs.writeShellScript "nix-gc" ''
    ${cleanup0sizeDrvs}

    ${config.nix.package}/bin/nix-collect-garbage ${config.nix.gc.options}
  '');
}
