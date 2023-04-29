
Commands that were performed on the machine for a successful deployment:

The determinate systems nix installer is used, see: https://github.com/DeterminateSystems/nix-installer

Login to the remote host and execute the following commands to set up nix and prepare for deployment
```command
# Set up passwordless sudo for the deploy user
echo "%admin            ALL = (ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

printf 'run\tprivate/var/run\n' | sudo tee -a /etc/synthetic.conf
sudo /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t

sudo mv /etc/nix/nix.conf{,.prev}
sudo mv /etc/zshenv{,.prev}
sudo mv /etc/zshrc{,.prev}
sudo mv /etc/bashrc{,.prev}

softwareupdate --install-rosetta --agree-to-license
```

Create a flake module for the new host similar to the one under `modules/flake-parts/darwinConfigurations.macos-04`

Ensure the nix-daemon is running.
```command
nix run .#ssh-macos-XX "sudo launchctl kickstart -k system/org.nixos.nix-daemon"
```

Run the initial deployment.
(replace `macos-XX` with the name of the new configuration)
```command
git add .
nix run .#deploy-macos-XX
```

After the deployment reload the nix-daemon again via:
```command
nix run .#ssh-macos-XX "sudo launchctl kickstart -k system/org.nixos.nix-daemon"
```

Add the new host as remote builder inside `modules/nixos/nix-build-distributor.nix`

Finalize the ssh authentication setup:

- Ssh into the distributor host via `nix run .#ssh-linux-builder-01`.
- Login to the builder via ssh to verify the host key initially: `ssh builder@{ip-of-new-host}`
- verify the key and press `Y`, then cancel with Ctrl+C as won't be an interactive session as per the remote SSH config

Verify that the new remote builder works:
```command
nix run .#ssh-linux-builder-01 "nix store ping --store 'ssh-ng://builder@IP_OF_NEW_BUILDER'"
```
