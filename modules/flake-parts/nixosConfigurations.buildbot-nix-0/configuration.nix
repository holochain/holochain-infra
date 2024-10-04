{
  config,
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
let
  domainSuffix =
    (builtins.elemAt
      (builtins.attrValues self.nixosConfigurations.dweb-reverse-tls-proxy.config.services.bind.zones)
      0
    ).name;
  appFqdn = "buildbot-nix-0.${domainSuffix}";
  appId = 1008744;

  oauthId = "Iv23liqmAiBw8ab9EF61";
  topic = "holo-chain-buildbot-nix-0";
in
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

    primaryIpv4 = "135.181.114.173";
    primaryIpv6 = "2a01:4f9:4b:1a93::1/64";
  };

  networking = {
    inherit (config.passthru) hostName domain;
  };
  hostName = config.passthru.primaryIpv4;

  nix.settings.max-jobs = 12;

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

  roles.nix-remote-builder.schedulerPublicKeys = [
    # TODO
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

  services.nginx.virtualHosts."${appFqdn}" = {
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
    domain = appFqdn;
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
        id = appId;
        secretKeyFile = config.sops.secrets.buildbot-github-app-secret-key.path;
      };
      webhookSecretFile = config.sops.secrets.buildbot-github-webhook-secret.path;
      # this is a client secret
      oauthSecretFile = config.sops.secrets.buildbot-github-oauth-secret.path;
      # this is displayed in the app as "Client ID"
      inherit oauthId topic;
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
  ];

  sops.secrets.holo-host-github-environment-secrets = { };
  systemd.services.nix-daemon.serviceConfig.EnvironmentFile =
    config.sops.secrets.holo-host-github-environment-secrets.path;
}
