{
  config,
  lib,
  ...
}: {
  users.knownGroups = ["builder"];
  users.knownUsers = ["builder"];
  users.groups.builder = {
    name = "builder";
    gid = lib.mkDefault 8765;
    description = "Group for remote build clients";
  };
  users.users.builder = {
    name = "builder";
    uid = lib.mkDefault 8765;
    home = lib.mkDefault "/Users/builder";
    createHome = true;
    shell = "/bin/bash";
    description = "User for remote build clients";
  };
  system.activationScripts.postActivation.text = ''
    echo 'PATH=/nix/var/nix/profiles/default/bin:$PATH' > /Users/builder/.bashrc
    mkdir -p /Users/builder/.ssh/
    chmod 700 /Users/builder/.ssh/
    chown builder:staff /Users/builder/.ssh/
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1K1ZYBnf3UqQbln5Z8DLYsXyJo6pRAFISPQ7lJZpoO root@linux-builder-01" > /Users/builder/.ssh/authorized_keys
  '';
}
