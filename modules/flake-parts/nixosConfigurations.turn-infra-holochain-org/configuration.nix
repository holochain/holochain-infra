{
  config,
  lib,
  inputs,
  self,
  pkgs,
  ...
}: let
  turnIpv4 = "37.27.24.128";
  ipv6Prefix = "2a01:4f9:c012:b61f";
  ipv6PrefixLength = "64";

  signalIpv4 = "95.217.30.224";
  signalIpv4Prefix = 32;
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

    self.nixosModules.holochain-turn-server
    self.nixosModules.tx5-signal-server
  ];

  networking.hostName = "turn-infra-holochain-org"; # Define your hostname.

  hostName = turnIpv4;

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [
    "https://holochain-ci.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # FIXME: is there a better way to do this?
  environment.etc."systemd/network/10-cloud-init-eth0.network.d/00-floating-ips.conf".text = ''
    [Network]
    Address = ${signalIpv4}/${builtins.toString signalIpv4Prefix}
  '';

  disko.devices.disk.sda = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "1G";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
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
                mountOptions = ["noatime"];
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
  };

  system.stateVersion = "23.05";

  services.holochain-turn-server = {
    enable = true;
    url = "turn.infra.holochain.org";
    address = turnIpv4;
    username = "test";
    credential = "test";
  };

  services.tx5-signal-server = {
    enable = true;
    address = signalIpv4;
    port = 8443;
    tls-port = 443;
    url = "signal.infra.holochain.org";
    iceServers = [
      {
        urls = [
          "stun:${config.services.holochain-turn-server.url}:80"
        ];
      }
      {
        urls = [
          "turn:${config.services.holochain-turn-server.url}:80"
          "turn:${config.services.holochain-turn-server.url}:80?transport=tcp"
          "turns:${config.services.holochain-turn-server.url}:443?transport=tcp"
        ];

        inherit
          (config.services.holochain-turn-server)
          username
          credential
          ;
      }
    ];
  };
}
