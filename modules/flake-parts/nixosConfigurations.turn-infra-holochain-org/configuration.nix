{
  config,
  lib,
  inputs,
  self,
  pkgs,
  ...
}: let
  ipv4 = "37.27.24.128";
  ipv6Prefix = "2a01:4f9:c012:b61f";
  ipv6PrefixLength = "64";
  fqdn2domain = "infra.holochain.org";
in {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.srvos.nixosModules.hardware-hetzner-cloud

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
  ];

  networking.hostName = "turn-infra-holochain-org"; # Define your hostname.

  hostName = ipv4;

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [
    "https://holochain-ci.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  boot.loader.grub = {
    efiSupport = false;
    device = "/dev/sda";
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = "${ipv6Prefix}::1/${ipv6PrefixLength}";

  disko.devices.disk.sda = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          name = "boot";
          start = "0";
          end = "1M";
          part-type = "primary";
          flags = ["bios_grub"];
        }
        {
          name = "root";
          start = "1M";
          end = "100%";
          part-type = "primary";
          bootable = true;
          content = {
            type = "btrfs";
            extraArgs = ["-f"]; # Override existing partition
            subvolumes = {
              # Subvolume name is different from mountpoint
              "/rootfs" = {
                mountpoint = "/";
              };
              "/nix" = {
                mountOptions = ["noatime"];
              };
            };
          };
        }
      ];
    };
  };

  system.stateVersion = "23.05";
}
