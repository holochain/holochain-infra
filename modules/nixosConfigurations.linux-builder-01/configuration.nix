{config, lib, inputs, self, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.roles-nix-remote-builder
    self.nixosModules.holo-users
  ];

  roles.nix-remote-builder.schedulerPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVxIpF1Rfqz6i8JfhYswzYUM9cuL5p11LfVGSfPmw4Q root@github-runner-host"
  ];

  boot.loader.grub = {
    devices = [ "/dev/nvme0n1" ];
    # efiSupport = true;
    # efiInstallAsRemovable = true;
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  disko.devices.disk.nvme0n1 = {
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          name = "boot";
          type = "partition";
          start = "0";
          end = "1M";
          part-type = "primary";
          flags = ["bios_grub"];
        }
        # {
        #   type = "partition";
        #   name = "ESP";
        #   start = "1MiB";
        #   end = "1000MiB";
        #   bootable = true;
        #   content = {
        #     type = "filesystem";
        #     format = "vfat";
        #     mountpoint = "/boot";
        #   };
        # }
        {
          name = "root";
          type = "partition";
          start = "1000MiB";
          end = "100%";
          part-type = "primary";
          bootable = true;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        }
      ];
    };
  };
}
