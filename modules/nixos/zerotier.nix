# ZeroTier module which keeps the IDs private.
{
  self,
  config,
  lib,
  ...
}:
let
  cfg = config.zerotier-stealth;
in
{
  options.zerotier-stealth = {
    enable = lib.mkEnableOption "Enable holo-zerotier";
    autostart = lib.mkOption { default = true; };

    secretSopsFile = lib.mkOption {
      description = "path to a secret that's used as 'binary' format.  containing one zerotier ID per line.";
      type = lib.types.path;
      default = self + "/secrets/${config.networking.hostName}/zerotier.txt";
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "zerotierone" ];

    services.zerotierone = {
      enable = cfg.enable;
      joinNetworks = [
        # moved to the service below as it's now secret
      ];
    };

    systemd.services.zerotierone.wantedBy = lib.mkIf (!cfg.autostart) (lib.mkForce [ ]);

    systemd.services.zerotieroneSecretNetworks = {
      enable = cfg.enable;
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

    sops.secrets.zerotieroneNetworks = {
      sopsFile = cfg.secretSopsFile;
      format = "binary";
    };
  };
}
