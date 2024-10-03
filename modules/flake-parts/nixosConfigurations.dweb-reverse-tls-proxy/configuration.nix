{
  config,
  lib,
  inputs,
  self,
  pkgs,
  ...
}:
let
  ipv4 = "5.78.43.185";
  fqdn2domain = "infra.holochain.org";
in
{
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

  networking.hostName = "dweb-reverse-tls-proxy"; # Define your hostname.

  hostName = ipv4;

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [ "https://holochain-ci.cachix.org" ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = false;

  disko.devices.disk.sda = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # for grub MBR
        };
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

  system.stateVersion = "23.11";

  ### ZeroTier
  services.zerotierone = {
    enable = lib.mkDefault true;
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (builtins.trace (lib.getName pkg) (lib.getName pkg)) [
      "zerotierone"
      "nomad"
    ];

  sops.secrets.zerotieroneNetworks = {
    sopsFile = ../../../secrets/dweb-reverse-tls-proxy/zerotier.txt;
    format = "binary";
  };
  systemd.services.zerotieroneSecretNetworks = {
    enable = true;
    requiredBy = [ "zerotierone.service" ];
    partOf = [ "zerotierone.service" ];

    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;

    script =
      let
        secret = config.sops.secrets.zerotieroneNetworks;
      in
      ''
        # include the secret's hash to trigger a restart on change
        # ${builtins.hashString "sha256" (builtins.toJSON secret)}

        ${config.systemd.services.zerotierone.preStart}

        rm -rf /var/lib/zerotier-one/networks.d/*.conf
        for network in `grep -v '#' ${secret.path}`; do
          touch /var/lib/zerotier-one/networks.d/''${network}.conf
        done
      '';
  };

  networking.firewall.allowedTCPPorts = [
    53
    80
    443
    8030

    # nomad
    4646
    4647
  ];

  networking.firewall.allowedUDPPorts = [ 53 ];

  # dynamic port ranges used by nomad services
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 20000;
      to = 32000;
    }
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 20000;
      to = 32000;
    }
  ];

  ### BIND and ACME

  # FIXME: changes to the bind zone require a manual `systemctl restart bind`
  system.activationScripts.bind-zones.text = ''
    mkdir -p /etc/bind/zones
    chown named:named /etc/bind/zones
  '';

  environment.etc."bind/zones/${fqdn2domain}.zone" = {
    enable = true;
    user = "named";
    group = "named";
    mode = "0644";
    text = ''
      $ORIGIN .
      $TTL 60 ; 1 minute
      ${fqdn2domain} IN SOA ns1.${fqdn2domain}. admin.holochain.org. (
                                        2001062504 ; serial
                                        21600      ; refresh (6 hours)
                                        3600       ; retry (1 hour)
                                        604800     ; expire (1 week)
                                        86400      ; minimum (1 day)
                                      )

                              NS      ns1.${fqdn2domain}.
      $ORIGIN ${fqdn2domain}.
      ns1                                      A       ${ipv4}
      ${fqdn2domain}.                          A       ${ipv4}

      *.${fqdn2domain}.                        CNAME   ${fqdn2domain}.

      testing.events.${fqdn2domain}.           A       127.0.0.1
      hackathons.events.${fqdn2domain}.        A       10.1.3.37
      hackathon.events.${fqdn2domain}.         A       10.1.3.37
      amsterdam2023.events.${fqdn2domain}.     A       10.1.3.187

      x64-linux-dev-01.dev.${fqdn2domain}.       A       ${self.nixosConfigurations.x64-linux-dev-01.config.passthru.primaryIpv4}
      s3.dev.${fqdn2domain}.                     A       ${self.nixosConfigurations.x64-linux-dev-01.config.passthru.primaryIpv4}
      s3-console.dev.${fqdn2domain}.             A       ${self.nixosConfigurations.x64-linux-dev-01.config.passthru.primaryIpv4}

      turn-0.${fqdn2domain}.                     A       ${self.nixosConfigurations.turn-0.config.services.holochain-turn-server.address}
      signal-0.${fqdn2domain}.                   A       ${self.nixosConfigurations.turn-0.config.services.tx5-signal-server.address}
      bootstrap-0.${fqdn2domain}.                A       ${self.nixosConfigurations.turn-0.config.services.kitsune-bootstrap.address}

      turn-1.${fqdn2domain}.                     A       ${self.nixosConfigurations.turn-1.config.services.holochain-turn-server.address}
      signal-1.${fqdn2domain}.                   A       ${self.nixosConfigurations.turn-1.config.services.tx5-signal-server.address}
      bootstrap-1.${fqdn2domain}.                A       ${self.nixosConfigurations.turn-1.config.services.kitsune-bootstrap.address}

      turn-2.${fqdn2domain}.                     A       ${self.nixosConfigurations.turn-2.config.services.holochain-turn-server.address}
      signal-2.${fqdn2domain}.                   A       ${self.nixosConfigurations.turn-2.config.services.tx5-signal-server.address}
      bootstrap-2.${fqdn2domain}.                A       ${self.nixosConfigurations.turn-2.config.services.kitsune-bootstrap.address}

      turn-3.${fqdn2domain}.                     A       ${self.nixosConfigurations.turn-3.config.services.holochain-turn-server.address}
      signal-3.${fqdn2domain}.                   A       ${self.nixosConfigurations.turn-3.config.services.tx5-signal-server.address}
      bootstrap-3.${fqdn2domain}.                A       ${self.nixosConfigurations.turn-3.config.services.kitsune-bootstrap.address}

      monitoring-0.${fqdn2domain}.               A       ${self.nixosConfigurations.monitoring-0.config.passthru.primaryIpv4}
      monitoring-0.${fqdn2domain}.               AAAA    ${self.nixosConfigurations.monitoring-0.config.passthru.primaryIpv6}
      monitoring.${fqdn2domain}.                 CNAME   monitoring-0.${fqdn2domain}.

      buildbot-nix-0.${fqdn2domain}.             A       ${self.nixosConfigurations.buildbot-nix-0.config.passthru.primaryIpv4}
    '';
  };

  services.bind = {
    enable = true;
    extraConfig = ''
      include "/var/lib/secrets/*-dnskeys.conf";
    '';
    zones = [
      {
        name = fqdn2domain;
        allowQuery = [ "any" ];
        file = "/etc/bind/zones/${fqdn2domain}.zone";
        master = true;
        extraConfig = "allow-update { key rfc2136key.${fqdn2domain}.; };";
      }
    ];
  };

  # Reload the bind config when the zone file changed
  systemd.services.bind.reloadTriggers = [
    config.environment.etc."bind/zones/${fqdn2domain}.zone".source
  ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@holochain.org";
    };

    certs."${fqdn2domain}" = {
      domain = "*.${fqdn2domain}";
      extraDomainNames = [ "*.cachix.${fqdn2domain}" ];
      dnsProvider = "rfc2136";
      credentialsFile = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
      # We don't need to wait for propagation since this is a local DNS server
      dnsPropagationCheck = false;
    };

    # can be used for debugging
    # preliminarySelfsigned = true;
    # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };

  systemd.services.dns-rfc2136-2-conf =
    let
      dnskeysConfPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.conf";
      dnskeysSecretPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
    in
    {
      requiredBy = [
        "acme-${fqdn2domain}.service"
        "bind.service"
      ];
      before = [
        "acme-${fqdn2domain}.service"
        "bind.service"
      ];
      unitConfig = {
        ConditionPathExists = "!${dnskeysConfPath}";
      };
      serviceConfig = {
        Type = "oneshot";
        UMask = 77;
      };
      path = [ pkgs.bind ];
      script = ''
        mkdir -p /var/lib/secrets
        chmod 755 /var/lib/secrets
        tsig-keygen rfc2136key.${fqdn2domain} > ${dnskeysConfPath}
        chown named:root ${dnskeysConfPath}
        chmod 400 ${dnskeysConfPath}

        # extract secret value from the dnskeys.conf
        while read x y; do if [ "$x" = "secret" ]; then secret="''${y:1:''${#y}-3}"; fi; done < ${dnskeysConfPath}

        cat > ${dnskeysSecretPath} << EOF
        RFC2136_NAMESERVER='127.0.0.1:53'
        RFC2136_TSIG_ALGORITHM='hmac-sha256.'
        RFC2136_TSIG_KEY='rfc2136key.${fqdn2domain}'
        RFC2136_TSIG_SECRET='$secret'
        EOF
        chmod 400 ${dnskeysSecretPath}
      '';
    };

  ### Caddy
  users.users.caddy.extraGroups = [ "acme" ];
  services.caddy.enable = true;
  services.caddy.virtualHosts = {
    "steveej.${fqdn2domain}:443" = {
      useACMEHost = fqdn2domain;
      extraConfig = ''
        reverse_proxy http://172.24.154.109:80 {
          transport http {
            keepalive 1d
          }
        }
      '';
    };

    # zippy 1 / emerge-3
    "dweb1.${fqdn2domain}:443" = {
      useACMEHost = fqdn2domain;
      extraConfig = ''
        reverse_proxy http://172.24.135.11:80 {
          transport http {
            keepalive 1d
          }
        }
      '';
    };

    # stub for redirecting the holochain-ci cachix to a DNS we're in control of.
    # the use-case is that we can now override this DNS at local events and insert a transparent nix cache
    "cachix.${fqdn2domain}:443" = {
      useACMEHost = fqdn2domain;
      extraConfig = ''
        respond /api/v1/cache/holochain-ci `{"githubUsername":"","isPublic":true,"name":"holochain-ci","permission":"Read","preferredCompressionMethod":"ZSTD","publicSigningKeys":["holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="],"uri":"https://holochain-ci.cachix.infra.holochain.org"}`

        redir / https://cachix.org{uri}
      '';
    };

    "holochain-ci.cachix.${fqdn2domain}:443" = {
      useACMEHost = fqdn2domain;
      extraConfig = ''
        redir https://holochain-ci.cachix.org{uri}
        # reverse_proxy https://holochain-ci.cachix.org
      '';
    };

    "acme-turn-0.${fqdn2domain}:80" = {
      extraConfig = ''
        reverse_proxy http://turn-0.${fqdn2domain}:${builtins.toString self.nixosConfigurations.turn-0.config.services.holochain-turn-server.nginx-http-port}
      '';
    };

    "acme-turn-1.${fqdn2domain}:80" = {
      extraConfig = ''
        reverse_proxy http://turn-1.${fqdn2domain}:${builtins.toString self.nixosConfigurations.turn-1.config.services.holochain-turn-server.nginx-http-port}
      '';
    };

    "acme-turn-2.${fqdn2domain}:80" = {
      extraConfig = ''
        reverse_proxy http://turn-2.${fqdn2domain}:${builtins.toString self.nixosConfigurations.turn-2.config.services.holochain-turn-server.nginx-http-port}
      '';
    };

    "acme-turn-3.${fqdn2domain}:80" = {
      extraConfig = ''
        reverse_proxy http://turn-3.${fqdn2domain}:${builtins.toString self.nixosConfigurations.turn-3.config.services.holochain-turn-server.nginx-http-port}
      '';
    };
  };

  sops.secrets.global-server-nomad-key = {
    sopsFile = ../../../secrets/nomad/servers/keys.yaml;
    owner = config.users.extraUsers.nomad.name;
    group = config.users.groups.nomad.name;
  };

  services.nomad = {
    enable = true;
    package = pkgs.nomad_1_6;
    enableDocker = false;
    dropPrivileges = false;

    extraPackages = [
      pkgs.coreutils
      pkgs.nix
      pkgs.bash
      pkgs.gitFull
      pkgs.cacert
    ];

    settings = {
      advertise = {
        http = config.hostName;
      };

      bind_addr = config.hostName;

      server = {
        enabled = true;
        bootstrap_expect = 1;

        server_join = {
          retry_join = [ config.hostName ];
        };
      };
      client = {
        enabled = true;

        node_class = "testing";

        meta = {
          inherit (pkgs.targetPlatform) system;

          features = builtins.concatStringsSep "," [
            "poc-1"
            "poc-2"
            "ipv4-public"
            "nix"
            "nixos"
          ];

          machine_type = "vps";
        };
      };
      plugin.raw_exec.config.enabled = true;

      tls = {
        http = true;
        rpc = true;
        ca_file = ../../../secrets/nomad/admin/nomad-agent-ca.pem;
        cert_file = ../../../secrets/nomad/servers/global-server-nomad.pem;
        key_file = config.sops.secrets.global-server-nomad-key.path;

        verify_server_hostname = true;
        verify_https_client = true;
      };
    };
  };

  users.extraUsers.nomad.isNormalUser = true;
  users.extraUsers.nomad.isSystemUser = false;
  users.extraUsers.nomad.group = "nomad";
  users.extraUsers.nomad.home = config.services.nomad.settings.data_dir;
  users.extraUsers.nomad.createHome = true;
  users.groups.nomad.members = [ "nomad" ];

  systemd.services.nomad.serviceConfig.User = "nomad";
  systemd.services.nomad.serviceConfig.Group = "nomad";
}
