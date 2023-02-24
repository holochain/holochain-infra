
Commands that were performed on the machine for a successful deployment:

```shell
sudo nix upgrade-nix
sudo ln -s /var/run/ /run
sudo mv /etc/nix/nix.conf{,.prev}
sudo mv /etc/zshrc{,.prev}
sudo dseditgroup -o edit -a builder -t user com.apple.access_ssh
sudo chsh -s /bin/zsh administrator
```
