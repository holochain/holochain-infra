{
  config,
  lib,
  inputs,
  self,
  pkgs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-online-amd
    inputs.srvos.nixosModules.roles-nix-remote-builder
    self.nixosModules.holo-users
    self.nixosModules.github-runner-multi-arch
    self.nixosModules.nix-build-distributor

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
    ../../nixos/cachix-watch.nix
  ];

  networking.hostName = "linux-builder-01"; # Define your hostname.

  hostName = "95.217.193.35";

  nix.settings.max-jobs = 32;

  roles.nix-remote-builder.schedulerPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVxIpF1Rfqz6i8JfhYswzYUM9cuL5p11LfVGSfPmw4Q root@github-runner-host"
  ];

  boot.loader.grub = {
    version = 2;
    efiSupport = false;
    device = "/dev/nvme0n1";
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:4a:5026::1/64";

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
        {
          name = "root";
          type = "partition";
          start = "1M";
          end = "100%";
          part-type = "primary";
          bootable = true;
          content = {
            type = "btrfs";
            extraArgs = "-f"; # Override existing partition
            subvolumes = {
              # Subvolume name is different from mountpoint
              "/rootfs" = {
                mountpoint = "/";
              };
              "/nix" = {
                mountOptions = ["compress=zstd" "noatime"];
              };
            };
          };
        }
      ];
    };
  };

  system.stateVersion = "23.05";
}
