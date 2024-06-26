{
  config,
  lib,
  ...
}: let
  name = "devMinio";
  cfg = config.services.${name};
in {
  options.services.${name} = {
    enable = lib.mkEnableOption "dev minio server";
    rootDomain = lib.mkOption {
      type = lib.types.str;
      default = "dev.infra.holochain.org";
    };

    s3Domain = lib.mkOption {
      type = lib.types.str;
      default = "s3.${cfg.rootDomain}";
    };

    listenPort = lib.mkOption {
      default = 9000;
      type = lib.types.int;
    };

    consolePort = lib.mkOption {
      default = 9001;
      type = lib.types.int;
    };

    # TODO: revisit this as it's probably an anti-pattern
    region = lib.mkOption {
      description = "re-export of region";
      default = config.services.minio.region;
    };
  };

  config = {
    sops.secrets.minio_root_credentials.sopsFile = ../../secrets/minio/server.yaml;

    services.minio = {
      enable = true;
      browser = true;
      listenAddress = "127.0.0.1:${builtins.toString cfg.listenPort}";
      consoleAddress = "127.0.0.1:${builtins.toString cfg.consolePort}";
      rootCredentialsFile = config.sops.secrets.minio_root_credentials.path;
    };

    services.caddy.enable = true;
    services.caddy.email = "admin@holochain.org";
    services.caddy.globalConfig = ''
      auto_https disable_redirects
    '';

    services.caddy.virtualHosts."s3.${cfg.rootDomain}" = {
      extraConfig = ''
        reverse_proxy http://${config.services.minio.listenAddress}
      '';
    };
    services.caddy.virtualHosts."s3-console.${cfg.rootDomain}" = {
      extraConfig = ''
        reverse_proxy http://${config.services.minio.consoleAddress}
      '';
    };

    networking.firewall.allowedTCPPorts = [
      443
    ];
  };
}
