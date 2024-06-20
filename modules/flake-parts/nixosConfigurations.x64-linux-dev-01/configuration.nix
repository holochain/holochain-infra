{
  inputs,
  self,
  pkgs,
  lib,
  ...
}: let
  domain = "dev.infra.holochain.org";
in {
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

    # garage
    (
      {config, ...}: {
        sops = {
          defaultSopsFile = self + "/secrets/${config.networking.hostName}/secrets.yaml";
          secrets = {
            garage_env = {};
          };
        };

        services.garage = {
          enable = true;
          package = self.inputs.nixpkgs-24-05.legacyPackages.${pkgs.stdenv.system}.garage_1_0_0;
          environmentFile = config.sops.secrets.garage_env.path;
          settings = {
            rpc_bind_addr = "[::]:3901";

            s3_api = {
              api_bind_addr = "[::]:3900";
              s3_region = "garage";
              root_domain = ".s3.garage";
            };

            s3_web = {
              bind_addr = "[::]:3902";
              root_domain = ".web.garage";
            };
            admin = {
              api_bind_addr = "0.0.0.0:3903";
            };
          };
        };

        services.caddy.enable = true;
        services.caddy.email = "mail@stefanjunker.de";
        services.caddy.globalConfig = ''
          auto_https disable_redirects
        '';
        services.caddy.virtualHosts."s3.${domain}" = {
          extraConfig = ''
            reverse_proxy "${config.services.garage.settings.s3_web.bind_addr};
          '';
        };
      }
    )
  ];

  nix.settings.system-features = [
    "big-parallel"
  ];

  networking = {
    hostName = "x64-linux-dev-01"; # Define your hostname.
    useNetworkd = true;

    nat.enable = true;
    firewall.enable = true;

    firewall.allowedTCPPorts = [
      5201
    ];
    firewall.allowedUDPPorts = [
      5201
    ];
  };

  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = true;
      };
    };
  };

  hostName = "135.181.118.162";

  nix.settings.max-jobs = 32;

  roles.nix-remote-builder.schedulerPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQ22z5rDdCLYH+MEoEt+tXJXTJqoeZNqvJl2n4aB+Kn steveej@steveej-x13s"
  ];

  virtualisation.libvirtd.enable = true;

  boot.loader.grub = {
    efiSupport = false;
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:4b:1e9b::/64";

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
            mountpoint = "/partition-root";
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

  system.stateVersion = "23.11";
}
