{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
# Hetzner AX162-R #2497582

# NOTE(steveej): i manually switched it to legacy via the KVM console because i did not want to spend more time on getting EFI to work with software RAID
# Legacy/BIOS
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

    (self + "/modules/nixos/shared-monitoring-clients.nix")

    inputs.buildbot-nix.nixosModules.buildbot-master
    inputs.buildbot-nix.nixosModules.buildbot-worker

  ];

  system.stateVersion = "24.05";

  passthru = {
    fqdn = "${config.passthru.hostName}.${config.passthru.domain}";

    domain = self.specialArgs.infraDomain;
    hostName = "buildbot-nix-0";

    primaryIpv4 = "65.109.100.254";
    primaryIpv6 = "2a01:4f9:3080:25e7::1/64";

    buildbot-nix = {
      appFqdn = "buildbot-nix-0.${config.passthru.domain}";
      appId = 1008744;
      oauthId = "Iv23liqmAiBw8ab9EF61";
      topic = "holo-chain-buildbot-nix-0";
    };
  };

  networking = {
    inherit (config.passthru) hostName domain;
  };
  hostName = config.passthru.primaryIpv4;

  nix.settings.max-jobs = 48;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = [ "nodev" ];
    # mirroredBoots = [
    #   {
    #     devices = [
    #       # "nodev"
    #       # "/dev/nvme0n1"
    #       # "/dev/nvme1n1"
    #     ];
    #     path = "/boot";
    #   }
    # ];
  };
  boot.loader.efi.canTouchEfiVariables = false;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = config.passthru.primaryIpv6;

  /*
    # not working NixOS

    root@rescue ~ # sgdisk --print /dev/nvme0n1
    Disk /dev/nvme0n1: 3750748848 sectors, 1.7 TiB
    Model: SAMSUNG MZQL21T9HCJR-00A07
    Sector size (logical/physical): 512/4096 bytes
    Disk identifier (GUID): 04AC4FB8-8843-4508-B894-A42F91218231
    Partition table holds up to 128 entries
    Main partition table begins at sector 2 and ends at sector 33
    First usable sector is 34, last usable sector is 3750748814
    Partitions will be aligned on 2048-sector boundaries
    Total free space is 4717 sectors (2.3 MiB)

    Number  Start (sector)    End (sector)  Size       Code  Name
        1            4096         2052095   1000.0 MiB  EF00  disk-sdb-ESP
        2         2052096      3750748159   1.7 TiB     8300  disk-sdb-rootfs
    root@rescue ~ # sgdisk --print /dev/nvme1n1
    Disk /dev/nvme1n1: 3750748848 sectors, 1.7 TiB
    Model: SAMSUNG MZQL21T9HCJR-00A07
    Sector size (logical/physical): 512/4096 bytes
    Disk identifier (GUID): C6FD320F-FEB3-4E49-822A-BC690ADF0559
    Partition table holds up to 128 entries
    Main partition table begins at sector 2 and ends at sector 33
    First usable sector is 34, last usable sector is 3750748814
    Partitions will be aligned on 2048-sector boundaries
    Total free space is 4717 sectors (2.3 MiB)

    Number  Start (sector)    End (sector)  Size       Code  Name
        1            4096         2052095   1000.0 MiB  EF00  disk-sda-ESP
        2         2052096      3750748159   1.7 TiB     8300  disk-sda-rootfs

    root@rescue ~ # blkid
    /dev/nvme0n1p1: UUID="38a0e387-1c9b-2095-cfc3-de9ef33f9f4d" UUID_SUB="75be7ee9-61c8-a320-f373-16a4ad55dab4" LABEL="any:esp" TYPE="linux_raid_member" PARTLABEL="disk-sdb-ESP" PARTUUID="925655a3-0b33-42d9-8c33-a39470f90209"
    /dev/nvme0n1p2: UUID="e5d82e40-9461-6e2a-43dc-209e555ea44d" UUID_SUB="e70e3b91-672d-cb3f-9caa-6653089ef3b8" LABEL="any:rootfs" TYPE="linux_raid_member" PARTLABEL="disk-sdb-rootfs" PARTUUID="92685db5-e967-4d07-a767-f3fc8998f875"
    /dev/md127: UUID="EBF0-E600" BLOCK_SIZE="512" TYPE="vfat"
    /dev/loop0: UUID="da55567a-52c0-4ad7-b417-9d6f531d1273" BLOCK_SIZE="4096" TYPE="ext2"
    /dev/md126: UUID="78beb252-b84f-4014-8d04-468cb714346b" UUID_SUB="3f598054-4252-453e-8c2a-93fe2cf9529d" BLOCK_SIZE="4096" TYPE="btrfs"
    /dev/nvme1n1p2: UUID="e5d82e40-9461-6e2a-43dc-209e555ea44d" UUID_SUB="5d3bd916-094a-a48b-490e-c378923c7a66" LABEL="any:rootfs" TYPE="linux_raid_member" PARTLABEL="disk-sda-rootfs" PARTUUID="4842c898-6320-41af-b564-e3a24ee05d11"
    /dev/nvme1n1p1: UUID="38a0e387-1c9b-2095-cfc3-de9ef33f9f4d" UUID_SUB="8c48e626-6807-4d0f-e708-f24cce7d364c" LABEL="any:esp" TYPE="linux_raid_member" PARTLABEL="disk-sda-ESP" PARTUUID="31d25776-1596-4278-8e01-008add39a42d"

    root@rescue ~ # parted /dev/nvme0n1
    GNU Parted 3.5
    Using /dev/nvme0n1
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) print
    Model: SAMSUNG MZQL21T9HCJR-00A07 (nvme)
    Disk /dev/nvme0n1: 1920GB
    Sector size (logical/physical): 512B/4096B
    Partition Table: gpt
    Disk Flags:

    Number  Start   End     Size    File system  Name             Flags
    1      2097kB  1051MB  1049MB               disk-sdb-ESP     boot, esp
    2      1051MB  1920GB  1919GB               disk-sdb-rootfs

    # mount
    /dev/md126 on /mnt/boot type vfat (rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
  */

  /*
    working hetzner

    root@Debian-bookworm-latest-amd64-base ~ # parted /dev/nvme0n1
    GNU Parted 3.5
    Using /dev/nvme0n1
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) print
    Model: SAMSUNG MZQL21T9HCJR-00A07 (nvme)
    Disk /dev/nvme0n1: 1920GB
    Sector size (logical/physical): 512B/4096B
    Partition Table: gpt
    Disk Flags:

    Number  Start   End     Size    File system  Name  Flags
    1      2097kB  271MB   268MB   fat16              boot, esp
    2      271MB   4565MB  4295MB                     raid
    3      4565MB  5639MB  1074MB                     raid
    4      5639MB  1920GB  1915GB                     raid

    root@Debian-bookworm-latest-amd64-base ~ # lsblk
    NAME        MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
    nvme0n1     259:0    0   1.7T  0 disk
    ├─nvme0n1p1 259:1    0   256M  0 part
    │ └─md0       9:0    0 255.9M  0 raid1 /boot/efi
    ├─nvme0n1p2 259:2    0     4G  0 part
    │ └─md1       9:1    0     4G  0 raid1 [SWAP]
    ├─nvme0n1p3 259:3    0     1G  0 part
    │ └─md2       9:2    0  1022M  0 raid1 /boot
    └─nvme0n1p4 259:4    0   1.7T  0 part
      └─md3       9:3    0   1.7T  0 raid1 /
    nvme1n1     259:5    0   1.7T  0 disk
    ├─nvme1n1p1 259:6    0   256M  0 part
    │ └─md0       9:0    0 255.9M  0 raid1 /boot/efi
    ├─nvme1n1p2 259:7    0     4G  0 part
    │ └─md1       9:1    0     4G  0 raid1 [SWAP]
    ├─nvme1n1p3 259:8    0     1G  0 part
    │ └─md2       9:2    0  1022M  0 raid1 /boot
    └─nvme1n1p4 259:9    0   1.7T  0 part
      └─md3       9:3    0   1.7T  0 raid1 /
  */

  disko.devices =
    let
      disk = id: {
        type = "disk";
        device = "/dev/nvme${id}n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 100;
              # Hetzner
              start = "2M";
              size = "500M";
              # Hetzner's Debian installation was using "EFI System" as the partition code for the ESP mdadm raid1 members.
              # so far _this_ is not working, however it did for Hetzner.
              type = "EF00";
              content = {
                type = "mdraid";
                name = "esp";
              };
            };

            # boot = {
            #   priority = 101;
            #   size = "100%";
            #   content = {
            #     type = "mdraid";
            #     name = "boot";
            #   };
            # };

            rootfs = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "rootfs";
              };
            };
          };
        };
      };
    in
    {
      disk = {
        sda = disk "0";
        sdb = disk "1";
      };

      mdadm = {
        esp = {
          type = "mdadm";
          level = 1;
          metadata = "1.0";
          content = {
            type = "filesystem";
            # hetzner
            format = "vfat";
            extraArgs = [
              "-F"
              "16"
            ];
            # FIXME: it should be possible to use /boot/efi here and leave /boot on the btrfs
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        # boot = {
        #   type = "mdadm";
        #   level = 1;
        #   content = {
        #     type = "filesystem";
        #     format = "ext3";
        #     mountpoint = "/boot";
        #   };
        # };

        rootfs = {
          type = "mdadm";
          level = 0;
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

  roles.nix-remote-builder.schedulerPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQ22z5rDdCLYH+MEoEt+tXJXTJqoeZNqvJl2n4aB+Kn steveej@steveej-x13s"
  ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "postmaster@holochain.org";
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx.virtualHosts."${config.passthru.buildbot-nix.appFqdn}" = {
    enableACME = true;
    forceSSL = true;
  };

  sops.defaultSopsFile = self + "/secrets/${config.networking.hostName}/secrets.yaml";

  sops.secrets.buildbot-github-oauth-secret = { };
  sops.secrets.buildbot-github-app-secret-key = { };
  sops.secrets.buildbot-github-webhook-secret = { };
  sops.secrets.buildbot-nix-workers = { };
  # sops.secrets.cachix-auth-token = {};

  services.buildbot-nix.master = {
    enable = true;
    admins = [
      "steveej"
      "evangineer"
      "r-vdp"
    ];
    buildSystems = [
      "x86_64-linux"
      # "aarch64-linux"
      # "x86_64-darwin"
      # "aarch64-darwin"
    ];
    domain = config.passthru.buildbot-nix.appFqdn;
    outputsPath = "/var/www/buildbot/nix-outputs/";
    evalMaxMemorySize = 6 * 1024;
    evalWorkerCount = 8;
    jobReportLimit = 0;
    workersFile = config.sops.secrets.buildbot-nix-workers.path;
    # cachix = {
    #   enable = true;
    #   name = "holochain-infra";
    #   auth.authToken.file = config.sops.secrets.cachix-auth-token.path;
    # };
    github = {
      authType.app = {
        id = config.passthru.buildbot-nix.appId;
        secretKeyFile = config.sops.secrets.buildbot-github-app-secret-key.path;
      };
      webhookSecretFile = config.sops.secrets.buildbot-github-webhook-secret.path;
      # this is a client secret
      oauthSecretFile = config.sops.secrets.buildbot-github-oauth-secret.path;
      # this is displayed in the app as "Client ID"
      inherit (config.passthru.buildbot-nix) oauthId topic;
    };

    postBuildSteps = [
      {
        name = "post-build-step-test";
        environment =
          let
            props = lib.attrsets.genAttrs [
              "attr"
              "basename"
              "branch"
              "builddir"
              "builderid"
              "buildername"
              "buildnumber"
              "cacheStatus"
              "codebase"
              "drv_path"
              "event"
              "github.base.sha"
              "github.head.sha"
              "out_path"
              "owners"
              "project"
              "projectid"
              "projectname"
              "pullrequesturl"
              "repository"
              "revision"
              "scheduler"
              "status_name"
              "system"
              "virtual_builder_name"
              "virtual_builder_tags"
              "workername"
            ] (name: self.inputs.buildbot-nix.lib.interpolate "%(prop:${name})s");
            props' = lib.attrsets.mapAttrs' (name: value: lib.nameValuePair "PROP_${name}" value) props;
          in
          props';
        command = [
          (builtins.toString (
            pkgs.writeShellScript "post-buld-step-test-script" ''
              set -eEu -o pipefail

              echo Running example postBuildStep...

              echo args: "$@"
              env
              pwd
              ls -lha
              ls -lha ..
              ls -lha ../..

              echo Done.
            ''
          ))
        ];
      }

    ];
  };

  # magic_rb:
  # If you dont pin it, then itll reset your db when it updates
  # Happened to me, as in the default config uses /var/lib/postgresql/{version}
  services.postgresql.package = pkgs.postgresql_15;

  sops.secrets.buildbot-nix-worker-password = { };
  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.sops.secrets.buildbot-nix-worker-password.path;
  };
  nix.settings.system-features = [
    "kvm"
    "nixos-test"
    "big-parallel"
  ];

  sops.secrets.holo-host-github-environment-secrets = { };
  systemd.services.nix-daemon.serviceConfig.EnvironmentFile =
    config.sops.secrets.holo-host-github-environment-secrets.path;
}
