{
  inputs,
  self,
  pkgs,
  lib,
  config,
  ...
}:
{
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

    (self + "/modules/nixos/shared-monitoring-clients.nix")

    {
      home-manager.users.dev =
        { pkgs, ... }:
        {
          home.packages = [
            # additional packages for this user go here
            pkgs.nil
            pkgs.wget
            pkgs.file
          ];
        };

      services.openssh.settings.AcceptEnv = builtins.concatStringsSep " " [
        "GIT_AUTHOR_*"
        "GIT_COMMITTER_*"
      ];
    }

    ../../nixos/dev-minio.nix
    { services.devMinio.enable = true; }

    inputs.nixos-vscode-server.nixosModules.default
    (
      { config, pkgs, ... }:
      {
        services.vscode-server = {
          enable = true;
          installPath = "$HOME/.vscodium-server";
          nodejsPackage = pkgs.nodejs_18;
        };
      }
    )
  ];

  nix.settings.system-features = [
    "big-parallel"
    "kvm"
    "nixos-test"
  ];

  networking = {
    inherit (config.passthru) hostName domain;
    useNetworkd = true;

    nat.enable = true;
    firewall.enable = true;

    firewall.allowedTCPPorts = [ 5201 ];
    firewall.allowedUDPPorts = [ 5201 ];
  };

  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = true;
      };
    };
  };

  hostName = config.passthru.fqdn;

  passthru = {
    fqdn = "${config.passthru.hostName}.dev.${config.passthru.domain}";
    hostName = "x64-linux-dev-01";
    domain = self.specialArgs.infraDomain;
    primaryIpv4 = "135.181.118.162";
  };

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
            extraArgs = [ "-f" ]; # Override existing partition
            mountpoint = "/partition-root";
            subvolumes = {
              # Subvolume name is different from mountpoint
              "/rootfs" = {
                mountpoint = "/";
              };
              "/nix" = {
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  system.stateVersion = "23.11";
}
