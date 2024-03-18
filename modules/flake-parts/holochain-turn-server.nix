{
  # System independent arguments.
  self,
  lib,
  inputs,
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    config,
    self',
    inputs',
    pkgs,
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    # packages = ...
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
    overlays.coturn = final: previous: {
      coturn = previous.coturn.overrideAttrs (
        super: {
          # coturn for NixOS needs to be built without libev_ok, otherwise acme-redirect won't work
          LIBEV_OK = "0";
          meta.platforms = lib.platforms.linux;
        }
      );
    };

    nixosModules.holochain-turn-server = {
      config,
      pkgs,
      lib,
      system,
      ...
    }: let
      cfg = config.services.holochain-turn-server;
    in {
      options.services.holochain-turn-server = {
        enable = lib.mkEnableOption "holochain turn server";
        url = lib.mkOption {
          type = lib.types.str;
        };
        turn-cert-dir = lib.mkOption {
          type = lib.types.str;
          default = config.security.acme.certs.${cfg.url}.directory;
        };
        address = lib.mkOption {
          type = lib.types.str;
        };

        nginx-http-port = lib.mkOption {
          type = lib.types.int;
          # skipping 81 because it's the default coturn alternative http port
          default = 82;
        };

        coturn-min-port = lib.mkOption {
          type = lib.types.int;
          default = 20000;
        };

        coturn-max-port = lib.mkOption {
          type = lib.types.int;
          default = 65535; # which is default but here listing explicitly
        };

        verbose = lib.mkEnableOption "verbose logging";

        acme-redirect = lib.mkOption {
          type = lib.types.str;
          default = "http://acme-${cfg.url}/.well-known/acme-challenge/";
        };

        username = lib.mkOption {
          type = lib.types.str;
          default = "test";
        };

        credential = lib.mkOption {
          type = lib.types.str;
          default = "test";
        };
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [self.overlays.coturn];

        networking.firewall.allowedTCPPorts = [
          80
          443
          9641 # prometheus

          cfg.nginx-http-port
        ];
        networking.firewall.allowedUDPPorts = [
          80
          443
          9641 # prometheus
        ];
        networking.firewall.allowedUDPPortRanges = [
          {
            from = cfg.coturn-min-port;
            to = cfg.coturn-max-port;
          }
        ];

        services.coturn = {
          enable = true;
          listening-port = 80;
          tls-listening-port = 443;
          listening-ips = [cfg.address];
          lt-cred-mech = true; # Use long-term credential mechanism.
          realm = cfg.url;
          cert = "${cfg.turn-cert-dir}/fullchain.pem";
          pkey = "${cfg.turn-cert-dir}/key.pem";
          no-cli = false;
          min-port = cfg.coturn-min-port;
          max-port = cfg.coturn-max-port;
          extraConfig =
            ''
              no-software-attribute
              no-multicast-peers
              no-tlsv1
              no-tlsv1_1
              user=${cfg.username}:${cfg.credential}
              prometheus
            ''
            + lib.strings.optionalString cfg.verbose ''
              verbose
            ''
            + lib.strings.optionalString (cfg.acme-redirect != null) ''
              acme-redirect=${cfg.acme-redirect}
            '';
        };

        systemd.services.coturn.serviceConfig = {
          LimitNOFILESoft = 10000;
        };

        # Add turnserver user to nginx group, because turnserver needs to have access to TLS certs from /var/lib/acme/
        users.groups.nginx.members = ["turnserver"];

        services.nginx = {
          enable = true;

          # the sole purpose of nginx here is TLS certificate renewal from letsencrypt
          # coturn redirects ACME, i.e. HTTP GET requests matching '^/.well-known/acme-challenge/(.*)'
          # to acme-turn.holo.host, which is intercepted by a reverse-proxy and redirected to port ${cfg.nginx-http-port} on this host
          virtualHosts."${cfg.url}" = {
            listen = [
              {
                addr = "${cfg.address}";
                port = cfg.nginx-http-port;
                ssl = false;
              }
            ];
            enableACME = true;
            serverName = cfg.url;
          };
        };

        security.acme = {
          acceptTerms = true;
          defaults = {
            # staging server has higher retry limits
            # server = "https://acme-staging-v02.api.letsencrypt.org/directory";

            email = "acme@holo.host";
            # after certificate renewal by acme coturn.service needs to reload this new cert, too
            # see https://github.com/NixOS/nixpkgs/blob/nixos-23.05/nixos/modules/security/acme/default.nix#L322
          };

          certs."${cfg.url}".reloadServices = ["coturn"];
        };
      };
    };
  };
}
