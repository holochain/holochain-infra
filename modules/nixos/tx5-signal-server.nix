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

    user = lib.mkOption {
      # TODO - change to tx5
      default = "root";
      type = lib.types.str;
    };

    group = lib.mkOption {
      # TODO - change to tx5
      default = "root";
      type = lib.types.str;
    };

    # TODO: consume this
    listenAddr = lib.mkOption {
      default = "";
      type = lib.types.str;
    };

    address = lib.mkOption {
      description = "address to bind";
      type = lib.types.str;
    };

    # TODO: distinguish between tls port and plain port. tx5 will listen on the latter and it'll be fronted by a reverse TLS proxy
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

    configText = lib.mkOption {
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

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/tx5-signal-srv --config ${cfg.configText}"; # TODO - point to dynamically created config
        Restart = "always";
      };
    };

    # TODO: set up a separate user or let systemd do this
    #users.groups.tx5 = { };
    #users.users.tx5 = {
    #  isSystemUser = true;
    #  group = "tx5";
    #  home = "${cfg.working-directory}";
    #  # ensures directory is owned by user
    #  createHome = true;
    #};

    #systemd.tmpfiles.rules = [
    #  "d ${cfg.working-directory}/uis 0755 tx5 tx5 - -"
    #];
  };
}
