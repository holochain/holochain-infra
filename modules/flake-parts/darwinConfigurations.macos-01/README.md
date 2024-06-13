
Commands that were performed on the machine for a successful deployment:

```shell
nix run .#ssh-macos-01
echo "%admin            ALL = (ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exit
nix run .#ssh-macos-01
exit
nix run .\#deploy-macos-01
nix run .#ssh-linux-builder-01 "timeout 10s ssh -o StrictHostKeyChecking=accept-new builder@167.235.13.208; nix store ping --store 'ssh-ng://builder@167.235.13.208'"
```
