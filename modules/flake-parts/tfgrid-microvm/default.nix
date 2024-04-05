{self, ...}: {
  flake.nixosModules = {
    zosVmDir = {
      config,
      lib,
      modulesPath,
      pkgs,
      ...
    }: let
      mkZosVmDir = import ./mk-zos-vm-dir.nix;

      bootFiles = pkgs.runCommandNoCC "bootfiles" {} ''
        mkdir $out
        ${pkgs.gcc}/bin/strip ${config.system.build.kernel.dev}/vmlinux -o $out/vmlinuz
        cp ${config.system.build.initialRamdisk}/initrd $out/initrd.img
      '';
    in {
      imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        self.nixosModules.zosVmDirOverlayAutodetect
      ];
      # can be built with
      # nix build -v .\#nixosConfigurations.<name>.config.system.build.zosVmDir
      system.build.zosVmDir = mkZosVmDir {inherit self pkgs config bootFiles;};

      fileSystems."/" = {
        device = "vroot";
        fsType = "virtiofs";
      };

      boot.initrd.kernelModules = [
        "virtiofs"
        "virtio_blk"
        "virtio_pmem"
        "virtio_console"
        "virtio_pci"
        "virtio_mmio"
      ];

      boot.loader.grub.enable = true;
      boot.initrd.systemd.enable = false;

      boot.loader.external.enable = true;
      # the first argument points to the new system's toplevel, which is equivalent to config.system.build.toplevel
      boot.loader.external.installHook = pkgs.writeShellScript "noop" ''
        ${pkgs.coreutils}/bin/ln -sf "$1"/init /init
        ${pkgs.coreutils}/bin/ln -sf ${bootFiles}/vmlinuz /boot/vmlinuz
        ${pkgs.coreutils}/bin/ln -sf  ${bootFiles}/initrd.img /boot/initrd.img
      '';

      services.cloud-init.enable = true;
      services.cloud-init.ext4.enable = true;
      services.cloud-init.network.enable = true;

      boot.kernelParams = ["nomodeset"];
      networking.useDHCP = false;

      # force SSH to start
      services.openssh.enable = true;
      systemd.services.sshd.wantedBy = lib.mkForce ["multi-user.target"];
      # systemd.services.sshd.after = lib.mkForce [ ];

      # changes for format.docker
      networking.useHostResolvConf = false;
    };

    zosVmDirOverlayAutodetect = {lib, ...}: {
      boot.initrd.kernelModules = [
        "overlay"
      ];

      # use an overlay on a tmpfs because the rfs mount is read-only
      boot.initrd.postMountCommands = let
        target = "/mnt-root";
        targetRo = "${target}-ro";

        # TODO: make this these are sane and work
        overlay = rec {
          base = "/overlay";
          upper = "${base}/rw/upper";
          work = "${base}/rw/work";
          lower = "${base}/ro";
        };
      in ''
        set -x
        if ! touch ${target}/.read-write; then
          # move the rootfs mount out of the way for the tmpfs
          mkdir -p ${targetRo}
          mount --move ${target} ${targetRo}

          # create a new tmpfs for the overlay
          mount -t tmpfs none -o size=4G,mode=755 ${target}

          # assemble and the overlay
          mkdir -p ${overlay.upper} ${overlay.work} ${overlay.lower}
          mount --move ${targetRo} ${overlay.lower}
          mount -t overlay overlay -o upperdir=${overlay.upper},workdir=${overlay.work},lowerdir=${overlay.lower} ${target}

          # TODO: make the overlay internals visible underneath its own mountpoint
          # currently the mount fails with: 'mount: mounting /overlay on /mnt-root/overlay failed: Invalid argument'
          # mkdir ${target}/overlay
          # mount --move ${overlay.base} ${target}/overlay
        fi
        set +x
      '';

      services.getty.autologinUser = "root";
      users.users.root.password = "root";
    };
  };
}
