{
  config,
  lib,
  inputs,
  self,
  pkgs,
  ...
}: let
  ipv4 = "5.78.43.185";
  ipv6Prefix = "2a01:4ff:1f0:872a";
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

  networking.hostName = "dweb-reverse-tls-proxy"; # Define your hostname.

  hostName = ipv4;

  nix.settings.max-jobs = 8;

  boot.loader.grub = {
    efiSupport = false;
    device = "/dev/sda";
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.network.networks."10-uplink".networkConfig.Address = "${ipv6Prefix}::1/64";

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

  ### ZeroTier
  services.zerotierone = {
    enable = lib.mkDefault true;
  };
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "zerotierone"
    ];

  sops.secrets.zerotieroneNetworks = {
    sopsFile = ../../../secrets/dweb-reverse-tls-proxy/zerotier.txt;
    format = "binary";
  };
  systemd.services.zerotieroneSecretNetworks = {
    enable = true;
    requiredBy = ["zerotierone.service"];
    partOf = ["zerotierone.service"];

    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;

    script = let
      secret = config.sops.secrets.zerotieroneNetworks;
    in ''
      # include the secret's hash to trigger a restart on change
      # ${builtins.hashString "sha256" (builtins.toJSON secret)}

      ${config.systemd.services.zerotierone.preStart}

      rm -rf /var/lib/zerotier-one/networks.d/*.conf
      for network in `grep -v '#' ${secret.path}`; do
        touch /var/lib/zerotier-one/networks.d/''${network}.conf
      done
    '';
  };

  networking.firewall.allowedTCPPorts = [53 80 443 8030];
  networking.firewall.allowedUDPPorts = [53];

  ### BIND and ACME

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
      $TTL 86400      ; 1 day
      ${fqdn2domain} IN SOA ns1.${fqdn2domain}. admin.holochain.org. (
                                        2001062504 ; serial
                                        21600      ; refresh (6 hours)
                                        3600       ; retry (1 hour)
                                        604800     ; expire (1 week)
                                        86400      ; minimum (1 day)
                                      )

                              NS      ns1.${fqdn2domain}.
      $ORIGIN ${fqdn2domain}.
      ns1            A             ${ipv4}
      ${fqdn2domain}.       A             ${ipv4}
      *.${fqdn2domain}.     CNAME         ${fqdn2domain}.
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
        allowQuery = ["any"];
        file = "/etc/bind/zones/${fqdn2domain}.zone";
        master = true;
        extraConfig = "allow-update { key rfc2136key.${fqdn2domain}.; };";
      }
    ];
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@holochain.org";
    };

    certs."${fqdn2domain}" = {
      domain = "*.${fqdn2domain}";
      extraDomainNames = [
        "*.cachix.${fqdn2domain}"
      ];
      dnsProvider = "rfc2136";
      credentialsFile = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
      # We don't need to wait for propagation since this is a local DNS server
      dnsPropagationCheck = false;
    };

    # can be used for debugging
    # preliminarySelfsigned = true;
    # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };

  systemd.services.dns-rfc2136-2-conf = let
    dnskeysConfPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.conf";
    dnskeysSecretPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
  in {
    requiredBy = ["acme-${fqdn2domain}.service" "bind.service"];
    before = ["acme-${fqdn2domain}.service" "bind.service"];
    unitConfig = {
      ConditionPathExists = "!${dnskeysConfPath}";
    };
    serviceConfig = {
      Type = "oneshot";
      UMask = 0077;
    };
    path = [pkgs.bind];
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
  users.users.caddy.extraGroups = ["acme"];
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

  };
}
