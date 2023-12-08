{ config, ... }: {
  systemd.services.nix-gc.preStart = ''
    echo Removing 0-size derivations if any exist...
    ${config.nix.package}/bin/nix-store --query --referrers-closure $(find /nix/store -maxdepth 1 -type f -name '*.drv' -size 0)  | xargs ${config.nix.package}/bin/nix-store --delete --ignore-liveness
  '';
}
