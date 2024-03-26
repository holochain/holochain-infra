{
  self,
  config,
  pkgs,
  bootFiles,
}: let
  pkgs2storeContents = map (x: {
    object = x;
    symlink = "none";
  });
  # trying to produce something that is compatible with
  # https://github.com/threefoldtech/zos/blob/main/docs/manual/zmachine/zmachine.md#vm
in
  pkgs.callPackage (self + "/lib/make-system-directory.nix") {
    contents = [
      {
        source = let
          cmd = pkgs.runCommandNoCC "rootfs" {} ''
            mkdir -p $out/boot
            cp -r ${bootFiles}/* $out/boot/

            ln -s ${config.system.build.toplevel}/init $out/init
            ${pkgs.gcc}/bin/strip ${config.system.build.kernel.dev}/vmlinux -o $out/boot/vmlinuz
            cp ${config.system.build.initialRamdisk}/initrd $out/boot/initrd.img
          '';
        in "${cmd}/.";
        target = "./";
      }
    ];

    # Add init script to image
    storeContents = pkgs2storeContents [
      config.system.build.toplevel
      pkgs.stdenvNoCC

      # TODO: find out why `systemctl reboot dbus` is needed to make `nixos-rebuild` work
      # these are also needed on the target for nixos-rebuild to work
      # pkgs.path
      # config.system.build.toplevel.drvPath
    ];
  }
