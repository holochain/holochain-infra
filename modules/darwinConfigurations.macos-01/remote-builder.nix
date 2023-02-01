{config, lib, ...}: {
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

    // TODO: write the multi-arch keys to /Users/builder/.ssh/authorized_keys with 0600 perms
  '';

  nix.settings.trusted-users = [ "builder" ];
}
