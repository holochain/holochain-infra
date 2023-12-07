{ config, lib, ...}: {
  launchd.daemons.nix-gc.command = lib.mkForce ''
    echo Removing 0-size derivations if any exist...
    ${config.nix.package}/bin/nix-store --query --referrers-closure $(find /nix/store -maxdepth 1 -type f -name '*.drv' -size 0)  | xargs nix-store --delete --ignore-liveness

    ${config.nix.package}/bin/nix-collect-garbage ${config.nix.gc.options}
  '';
}
