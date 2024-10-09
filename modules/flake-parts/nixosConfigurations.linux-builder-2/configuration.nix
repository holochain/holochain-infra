{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
# Hetzner AX41-NVMe #2491007
# BIOS/Legacy - came with this setting from the factory
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-online-amd
    inputs.srvos.nixosModules.roles-nix-remote-builder
    self.nixosModules.holo-users
    self.nixosModules.github-runner-multi-arch
    {
      config.services.github-runner-multi-arch = {
        enable = true;
        countOffset = 0;
        count = 1;
        url = "https://github.com/holochain/wind-tunnel";
      };
    }

    inputs.sops-nix.nixosModules.sops

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
    ../../nixos/shared-linux.nix

    self.nixosModules.shared-monitoring-clients

    self.nixosModules.zerotier
    {
      zerotier-stealth.enable = true;
      zerotier-stealth.autostart = true;

      # zerotier makes outgoing requests to private ranges, this trips up the detection system at hetzner.
      networking.nftables = {
        enable = true;
        tables.filter.family = "inet";
        tables.filter.content =
          let
            uplinkInterface = "enp35s0";
            privateDaddrs = builtins.concatStringsSep "," [
              "192.168.0.0/16"
              "10.0.0.0/8"
              "100.64.0.0/10"
              "172.16.0.0/12"
              "192.0.0.0/24"
              "198.18.0.0/15"
            ];
          in
          ''
            chain output {
              type filter hook output priority 0;
              policy accept;

              oifname ${uplinkInterface} ip daddr { ${privateDaddrs} } counter drop
            }
          '';
      };
    }
  ];

  passthru = {
    fqdn = "${config.passthru.hostName}.${config.passthru.domain}";

    domain = self.specialArgs.infraDomain;
    hostName = "linux-builder-2"; # Define your hostname.

    primaryIpv4 = "135.181.114.173";
    primaryIpv6 = "2a01:4f9:4b:1a93::1/64";
  };

  networking = {
    inherit (config.passthru) hostName domain;
  };
  hostName = config.passthru.primaryIpv4;

  nix.settings.max-jobs = 16;

  roles.nix-remote-builder.schedulerPublicKeys = [
    # we shouldn't allow anything non-test related here because the benchmark workloads on this builder expect to have exclusive hardware access
  ];

  boot.loader.grub = {
    efiSupport = false;
  };
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
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # Override existing partition
                  subvolumes = {
                    # Subvolume name is different from mountpoint
                    "/rootfs" = {
                      mountpoint = "/";
                    };
                    "/nix" = {
                      mountOptions = [ "noatime" ];
                      mountpoint = "/nix";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

  sops.secrets.github-runners-token = {
    key = "gh_hra2_pat5";
    sopsFile = ../../../secrets/${config.networking.hostName}/secrets.yaml;
  };

  system.stateVersion = "24.05";
}
