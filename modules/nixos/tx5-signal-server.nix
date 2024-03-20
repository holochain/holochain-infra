{
  self,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tx5-signal-server;
in {
  options.services.tx5-signal-server = {
    enable = lib.mkEnableOption "tx5-signal-server";

    package = lib.mkOption {
      default = self.packages.${pkgs.system}.tx5-signal-srv;
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
      description = "url for incoming TLS connections to the signal server";
      type = lib.types.str;
    };

    port = lib.mkOption {
      description = "port to bind";
      type = lib.types.int;
    };

    iceServers = lib.mkOption {
      description = "webrtc configuration to broadcast";
      type = lib.types.listOf lib.types.attrs;
      default = [];
    };

    demo = lib.mkEnableOption "enable demo broadcasting as a stand-in for bootstrapping";

    configTextFile = lib.mkOption {
      default = builtins.toFile "tx5.config.json" (builtins.toJSON {
        port = cfg.port;
        iceServers.iceServers = cfg.iceServers;
        demo = cfg.demo;
      });
    };
  };

  config = lib.mkIf (cfg.enable) {
    systemd.services.tx5-signal-server = {
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        TMPDIR = "%T";
        CONFIG_PATH = "%T/config.json";
      };

      serviceConfig = {
        DynamicUser = true;
        PrivateTmp = true;
        ExecStartPre = pkgs.writeShellScript "tx5-start-pre" ''
          set -xue
          export PATH=${lib.makeBinPath [pkgs.coreutils]}

          cp ${cfg.configTextFile} $CONFIG_PATH
          chmod 0400 $CONFIG_PATH
        '';

        ExecStart = "${cfg.package}/bin/tx5-signal-srv --config $CONFIG_PATH";
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
            port = 443;
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
