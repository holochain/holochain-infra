{
  self,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kitsune-bootstrap;
in {
  options.services.kitsune-bootstrap = {
    enable = lib.mkEnableOption "kitsune-bootstrap";

    package = lib.mkOption {
      default = self.inputs.holochain.packages.${pkgs.system}.holochain;
      type = lib.types.package;
    };

    address = lib.mkOption {
      description = "address to bind";
      type = lib.types.str;
    };

    tls-port = lib.mkOption {
      description = "port to bind for incoming TLS connections";
      type = lib.types.int;
    };

    url = lib.mkOption {
      description = "url for incoming TLS connections to the bootstrap server";
      type = lib.types.str;
    };

    port = lib.mkOption {
      description = "port to bind";
      type = lib.types.int;
    };
  };

  config = lib.mkIf (cfg.enable) {
    systemd.services.kitsune-bootstrap = {
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        TMPDIR = "%T";
      };

      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${cfg.package}/bin/kitsune-bootstrap -i 127.0.0.1:${builtins.toString cfg.port}";
        Restart = "always";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.url}" = {
        serverName = cfg.url;
        enableACME = true;
        addSSL = true;

        listen = [
          {
            addr = "${cfg.address}";
            port = 80;
            ssl = false;
          }

          {
            addr = "${cfg.address}";
            port = cfg.tls-port;
            ssl = true;
          }
        ];

        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "acme@holo.host";
      };

      # staging server has higher retry limits. uncomment the following when debugging ACME challenges.
      # certs."${cfg.url}".server = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };
  };
}
