{
  config,
  inputs,
  self,
  pkgs,
  lib,
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

    inputs.sops-nix.nixosModules.sops

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
    ../../nixos/shared-linux.nix
  ];

  networking.hostName = "linux-builder-01"; # Define your hostname.

  hostName = "95.217.193.35";

  nix.settings.max-jobs = 32;

  roles.nix-remote-builder.schedulerPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVxIpF1Rfqz6i8JfhYswzYUM9cuL5p11LfVGSfPmw4Q root@github-runner-host"
  ];

  boot.loader.grub = {
    efiSupport = false;
    # forcing seems required or else there's an error about duplicated devices
    devices = lib.mkForce ["/dev/nvme0n1"];
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:4a:5026::1/64";

  disko.devices.disk.nvme0n1 = {
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # for grub MBR
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f"]; # Override existing partition
            subvolumes = {
              # Subvolume name is different from mountpoint
              "/rootfs" = {
                mountpoint = "/";
              };
              "/nix" = {
                mountOptions = ["compress=zstd" "noatime"];
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
  };

  sops.secrets.github-runners-token = {
    key = "gh_hra2_pat3";
    sopsFile = ../../../secrets/${config.networking.hostName}/secrets.yaml;
  };

  system.stateVersion = "23.05";
}
