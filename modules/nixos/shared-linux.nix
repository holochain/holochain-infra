{ config, pkgs, ... }: {
  systemd.services.nix-gc.preStart = ''
    # if the machine runs low on disk space it's possible for derivation files to be created but never get content which results in derivations that can't be removed by the gc. this is a workaround which finds and deletes those problem derivations.
    echo Removing 0-size derivations if any exist...
    ${config.nix.package}/bin/nix-store --query --referrers-closure $(find /nix/store -maxdepth 1 -type f -name '*.drv' -size 0)  | ${pkgs.findutils}/bin/xargs ${config.nix.package}/bin/nix-store --delete --ignore-liveness
  '';
}
