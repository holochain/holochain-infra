{
  inputs,
  self,
  pkgs,
  lib,
  config,
  ...
}: let
in {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-online-amd
    inputs.srvos.nixosModules.roles-nix-remote-builder
    self.nixosModules.holo-users
    self.nixosModules.holo-users-interactive

    self.nixosModules.nix-build-distributor

    inputs.sops-nix.nixosModules.sops

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
    ../../nixos/shared-linux.nix

    {
      home-manager.users.dev = {pkgs, ...}: {
        home.packages = [
          # additional packages for this user go here
        ];
      };
    }

    # garage
    (
      {config, ...}: let
        domain = "garage.dev.infra.holochain.org";
        s3_web_port = "3902";
      in {
        users.groups.garage-secrets.members = [
          "dev"
        ];

        sops = {
          defaultSopsFile = self + "/secrets/${config.networking.hostName}/secrets.yaml";
          secrets = {
            GARAGE_ADMIN_TOKEN = {
              group = "garage-secrets";
              mode = "440";
            };
            GARAGE_METRICS_TOKEN = {
              group = "garage-secrets";
              mode = "440";
            };
            GARAGE_RPC_SECRET = {
              group = "garage-secrets";
              mode = "440";
            };
          };
        };

        systemd.services.garage.serviceConfig.Group = "garage-secrets";
        /*
        post deployment actions taken to get the node ready for storing files

        ```
        garage status
        garage layout assign fdf468cca3934a18 -c 100G -z dc0
        garage layout apply --version 1
        ```
        */
        services.garage = {
          enable = true;
          package = self.inputs.nixpkgs-24-05.legacyPackages.${pkgs.stdenv.system}.garage_1_0_0;
          settings = {
            # it's *NOT* world-readable, however not was garage exepects either
            # Jun 20 17:27:39 x64-linux-dev-01 garage[1701365]: Error: File /run/secrets/GARAGE_RPC_SECRET is world-readable! (mode: 0100440, expected 0600)
            allow_world_readable_secrets = true;

            rpc_bind_addr = "[::]:3901";
            rpc_secret_file = config.sops.secrets.GARAGE_RPC_SECRET.path;

            s3_api = {
              api_bind_addr = "[::]:3900";
              s3_region = "garage";
              # root_domain = ".s3.${domain}";
            };

            s3_web = {
              bind_addr = "[::]:${s3_web_port}";
              # root_domain = ".web.${domain}";
            };
            admin = {
              api_bind_addr = "0.0.0.0:3903";
              metrics_token_file = config.sops.secrets.GARAGE_METRICS_TOKEN.path;
              admin_token_file = config.sops.secrets.GARAGE_ADMIN_TOKEN.path;
            };
          };
        };

        services.caddy.enable = true;
        services.caddy.email = "admin@holochain.org";
        services.caddy.globalConfig = ''
          auto_https disable_redirects
        '';
        services.caddy.virtualHosts."${domain}" = {
          extraConfig = ''
            reverse_proxy http://127.0.0.1:${s3_web_port}
          '';
        };

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
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
