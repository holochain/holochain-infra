{
  self,
  config,
  pkgs,
  ...
}:
let
  root_domain = "dev.infra.holochain.org";
  s3_web_port = "3902";
  s3_port = "3900";
in
{
  users.groups.garage-secrets.members = [ "dev" ];

  sops = {
    defaultSopsFile = self + "/secrets/${config.networking.hostName}/secrets.yaml";
    secrets = {
      GARAGE_ADMIN_TOKEN = {
        group = "garage-secrets";
        mode = "440";
      };
      GARAGE_METRICS_TOKEN = {
        group = "garage-secrets";
        mode = "440";
      };
      GARAGE_RPC_SECRET = {
        group = "garage-secrets";
        mode = "440";
      };
    };
  };

  systemd.services.garage.serviceConfig.Group = "garage-secrets";
  /*
    post deployment actions taken to get the node ready for storing files

    ```
    garage status
    garage layout assign fdf468cca3934a18 -c 100G -z dc0
    garage layout apply --version 1
    ```
  */
  services.garage = {
    enable = true;
    package = self.inputs.nixpkgs-24-05.legacyPackages.${pkgs.stdenv.system}.garage_1_0_0;
    settings = {
      # it's *NOT* world-readable, however not was garage exepects either
      # Jun 20 17:27:39 x64-linux-dev-01 garage[1701365]: Error: File /run/secrets/GARAGE_RPC_SECRET is world-readable! (mode: 0100440, expected 0600)
      allow_world_readable_secrets = true;

      rpc_bind_addr = "[::]:3901";
      rpc_secret_file = config.sops.secrets.GARAGE_RPC_SECRET.path;

      s3_api = {
        api_bind_addr = "[::]:${s3_port}";
        s3_region = "garage";
        root_domain = ".s3.${root_domain}";
      };

      s3_web = {
        bind_addr = "[::]:${s3_web_port}";
        root_domain = ".web.${root_domain}";
      };
      admin = {
        api_bind_addr = "0.0.0.0:3903";
        metrics_token_file = config.sops.secrets.GARAGE_METRICS_TOKEN.path;
        admin_token_file = config.sops.secrets.GARAGE_ADMIN_TOKEN.path;
      };
    };
  };

  services.caddy.enable = true;
  services.caddy.email = "admin@holochain.org";
  services.caddy.globalConfig = ''
    auto_https disable_redirects
  '';

  services.caddy.virtualHosts."s3web.${root_domain}" = {
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${s3_web_port}
    '';
  };
  services.caddy.virtualHosts."s3.${root_domain}" = {
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${s3_port}
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
