#!/usr/bin/env bash
set -eE -o pipefail

FLAKE=${1:-.#tfgrid-hpos-base}

# TODO: make sure SSH is reachable

set -x
sops -d ../secrets/static-age-keys.yaml | yq .tfgrid-shared | ssh root@$(pulumi stack -s dev output mycelium_ip) "cat > /etc/age.key; chmod 400 /etc/age.key"
nixos-rebuild boot --fast --no-build-nix --flake "${FLAKE}" --target-host root@$(pulumi stack -s dev output mycelium_ip)
ssh root@$(pulumi stack -s dev output mycelium_ip) "systemctl --force --force reboot" &
set +x

echo Waiting for the machine to reboot
sleep 5
while ! ping -q -W1 -c1 -6 $(pulumi stack -s dev output mycelium_ip) >/dev/null 2>&1; do
    printf .
done
echo  complete!
