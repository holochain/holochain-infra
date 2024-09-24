{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-online-amd
    inputs.srvos.nixosModules.roles-nix-remote-builder
    self.nixosModules.holo-users
    self.nixosModules.nix-build-distributor

    inputs.sops-nix.nixosModules.sops

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
    ../../nixos/shared-linux.nix
  ];

  system.stateVersion = "24.05";

  passthru = {
    hostName = "buildbot-nix-0";
    primaryIpv4 = "135.181.114.173";
    primaryIpv6 = "2a01:4f9:4b:1a93::1/64";
  };

  networking.hostName = config.passthru.hostName; # Define your hostname.

  hostName = "${config.passthru.hostName}.${
    (builtins.elemAt
      (builtins.attrValues self.nixosConfigurations.dweb-reverse-tls-proxy.config.services.bind.zones)
      0
    ).name
  }";

  nix.settings.max-jobs = 16;

  boot.loader.grub = {
    efiSupport = false;
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = config.passthru.primaryIpv6;

  disko.devices =
    let
      disk = id: {
        type = "disk";
        device = "/dev/${id}";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid0";
              };
            };
          };
        };
      };
    in
    {
      disk = {
        sda = disk "nvme0n1";
        sdb = disk "nvme1n1";
      };
      mdadm = {
        raid0 = {
          type = "mdadm";
          level = 0;
          content = {
            type = "gpt";
            partitions = {
              primary = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "btrfs";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };

  roles.nix-remote-builder.schedulerPublicKeys = [
    # TODO
  ];
}
