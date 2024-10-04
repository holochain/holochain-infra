{
  config,
  inputs,
  self,
  pkgs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    self.nixosModules.hardware-hetzner-cloud-cpx

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix

    (self + "/modules/nixos/shared-monitoring-clients.nix")
  ];

  networking.hostName = config.passthru.hostName; # Define your hostname.

  hostName = config.passthru.primaryIpv4;

  nix.settings.max-jobs = 3;

  nix.settings.substituters = [ "https://holochain-ci.cachix.org" ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-2:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "24.05";

  passthru = {
    fqdn = "${config.passthru.hostName}.${config.passthru.domain}";
    hostName = "monitoring-0";
    domain = self.specialArgs.infraDomain;
    primaryIpv4 = "135.181.110.69";
    primaryIpv6 = "2a01:4f9:c012:fd91::1";
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "acme@holo.host";
    };
  };

  sops.secrets = {
    grafana_admin_password = {
      sopsFile = ../../../secrets/monitoring/secrets.yaml;
      owner = config.users.users.grafana.name;
    };
  };

  services = {
    grafana = {
      enable = true;
      settings = {
        security.admin_password = "$__file{${config.sops.secrets.grafana_admin_password.path}}";
        server.http_port = 2432;
        date_formats.default_timezone = "utc";
        server = {
          domain = config.passthru.fqdn;
          root_url = "https://${config.passthru.fqdn}";
        };
      };
      provision = {
        enable = true;

        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString config.services.prometheus.port}";
            jsonData = {
              timeInterval = config.services.prometheus.globalConfig.scrape_interval;
            };
          }
        ];

        dashboards.settings.providers = [
          {
            name = "System monitoring";
            options.path = pkgs.fetchurl {
              name = "dashboard-node-exporter-full.json";
              url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
              hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
            };
          }
        ];

        #alerting.rules.path = ../data/alerts;
      };
    };

    prometheus = {
      enable = true;
      port = 2433;
      globalConfig = {
        scrape_interval = "30s";
        scrape_timeout = "10s";
      };
      extraFlags = [ "--web.enable-remote-write-receiver" ];
      retentionTime = "90d";
    };

    nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      proxyTimeout = "600s";
      virtualHosts = {
        "${config.passthru.fqdn}" = {
          serverAliases = [ "monitoring.${config.passthru.domain}" ];
          default = true;
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass =
            "http://${config.services.grafana.settings.server.http_addr}:"
            + toString config.services.grafana.settings.server.http_port;
          locations."/api/live" = {
            proxyPass =
              "http://${config.services.grafana.settings.server.http_addr}:"
              + toString config.services.grafana.settings.server.http_port;
            proxyWebsockets = true;
          };
          locations."/api/v1/write" = {
            proxyPass = "http://[::1]:${toString config.services.prometheus.port}";
            basicAuthFile = "/run/nginx/htpasswd";
          };
        };
      };
    };
  };

  systemd.services = {
    nginx = {
      serviceConfig = {
        StateDirectory = "nginx";
        LoadCredential = [
          "prometheus_remote_write_password:${config.sops.secrets.prometheus_remote_write_password.path}"
        ];
      };

      # Create the htpasswd file for basic auth from the password that's stored in SOPS.
      # The nginx service runs with PrivateTmp set to true, so this file will only
      # be accessible to nginx.
      preStart = ''
        ${pkgs.apacheHttpd}/bin/htpasswd \
          -icm "$RUNTIME_DIRECTORY/htpasswd" prometheus \
          < $CREDENTIALS_DIRECTORY/prometheus_remote_write_password
      '';
    };
  };
}
