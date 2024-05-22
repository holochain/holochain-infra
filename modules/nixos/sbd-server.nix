{
  self,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.sbd-server;
  types = lib.types;
in {
  options.services.sbd-server = {
    enable = lib.mkEnableOption "sbd-server";

    package = lib.mkOption {
      default = self.packages.${pkgs.system}.sbd-serverd;
      type = types.package;
    };

    address = lib.mkOption {
      description = "address to bind";
      type = types.str;
    };

    tls-port = lib.mkOption {
      description = "port to bind for incoming TLS connections";
      type = types.int;
    };

    url = lib.mkOption {
      description = "url for incoming TLS connections to the signal server";
      type = types.str;
    };

    trusted-ip-header = lib.mkOption {
      description = "request header key to extract the trusted IP from";
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = lib.mkIf (cfg.enable) {
    # TODO: can be tested with check-services tool on the sbd integration branch

    systemd.services.sbd-server = {
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        TMPDIR = "%T";
      };

      serviceConfig = {
        DynamicUser = true;
        PrivateTmp = true;

        # use this mechanism to let systemd take care of file permissions for the dynamic user it creates
        LoadCredential = [
          "cert.pem:${config.security.acme.certs."${cfg.url}".directory}/cert.pem"
          "key.pem:${config.security.acme.certs."${cfg.url}".directory}/key.pem"
        ];
        Restart = "always";

        AmbientCapabilities =
          # needed for binding to ports <1024
          lib.lists.optionals (cfg.tls-port
            < 1024) [
            "CAP_NET_BIND_SERVICE"
          ];

        ExecStart = builtins.concatStringsSep " " (
          [
            (lib.meta.getExe cfg.package)

            # bind to the public interface
            "--bind=${cfg.address}:${builtins.toString cfg.tls-port}"

            # configure TLS certificates
            ''--cert-pem-file="''${CREDENTIALS_DIRECTORY}/cert.pem"''
            ''--priv-key-pem-file="''${CREDENTIALS_DIRECTORY}/key.pem"''
          ]
          ++ lib.lists.optionals (cfg.trusted-ip-header != null) [
            ''--trusted-ip-header=${cfg.trusted-ip-header}''
          ]
        );
      };
    };

    networking.firewall.allowedTCPPorts = [
      80

      cfg.tls-port
    ];

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.url}" = {
        serverName = cfg.url;
        enableACME = true;
        addSSL = true;

        locations."/".root = "/var/www/${cfg.url}";

        listen = [
          {
            addr = "${cfg.address}";
            port = 80;
            ssl = false;
          }
        ];
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "acme@holo.host";
      };

      # note: the directory watching tls reload story has not yet been implemented. when tls certs are updated, the service must be restarted
      certs."${cfg.url}" = {
        reloadServices = ["sbd-server"];

        # staging server has higher retry limits. uncomment the following when debugging ACME challenges.
        # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      };
    };
  };
}
