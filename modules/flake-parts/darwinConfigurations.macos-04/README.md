

Commands that were performed on the machine for a successful deployment:

```shell
nix run .#ssh-macos-04
echo "%admin            ALL = (ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exit
nix run .#ssh-macos-04
exit
nix run .\#deploy-macos-04
nix run .\#linux-builder-01-ping-buildmachines
```
