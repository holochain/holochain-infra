
Commands that were performed on the machine for a successful deployment:

```shell
nix run .#ssh-macos-06
echo "%admin            ALL = (ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exit
nix run .#ssh-macos-06
exit
nix run .\#deploy-macos-06
nix run .#ssh-macos-06 "sudo mv /etc/nix/nix.conf{,.prev}; sudo mv /etc/zshrc{,.prev}; sudo mv /etc/zshenv{,.prev}"
nix run .#ssh-linux-builder-01 "timeout 10s ssh -o StrictHostKeyChecking=accept-new builder@208.52.154.135; nix store ping --store 'ssh-ng://builder@208.52.154.135'"
```
