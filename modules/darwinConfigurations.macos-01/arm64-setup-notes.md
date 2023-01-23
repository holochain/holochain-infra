# Set up macos + github runner
Given a hetzner machine with a macos arm64:
### install xcode developer tools via cmdline
https://apple.stackexchange.com/questions/107307/how-can-i-install-the-command-line-tools-completely-from-the-command-line
### install nix
https://nixos.org/download.html
### create /run
see https://github.com/LnL7/nix-darwin/issues/451
```shell
printf 'run\tprivate/var/run\n' | sudo tee -a /etc/synthetic.conf
/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t
```

### set up nix-darwin & home manager
https://gist.github.com/jmatsushita/5c50ef14b4b96cb24ae5268dab613050

### follow this guide to set up the runner
https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners
- 

### install rosetta
This will provide compatibility with x86_64-darwin
```command
softwareupdate --install-rosetta --agree-to-license
```

(for VM support, see tart.run)
### install tart
see: https://tart.run/quick-start/
```command
$ CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
$ echo '# Set PATH, MANPATH, etc., for Homebrew.' >> /Users/hetzner/.zprofile
$ echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/hetzner/.zprofile
$ eval "$(/opt/homebrew/bin/brew shellenv)"
```
