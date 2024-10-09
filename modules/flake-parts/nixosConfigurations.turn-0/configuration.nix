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
    self.nixosModules.hardware-hetzner-cloud-ccx

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix

    self.nixosModules.shared-monitoring-clients

    self.nixosModules.holochain-turn-server
    self.nixosModules.tx5-signal-server
    self.nixosModules.kitsune-bootstrap
  ];

  passthru = {
    fqdn = "${config.passthru.hostName}.${config.passthru.domain}";

    domain = self.specialArgs.infraDomain;
    hostName = "turn-0";

    primaryIpv4 = "37.27.24.128";

    turnIpv4 = config.passthru.primaryIpv4;
    signalIpv4 = "95.217.30.224";
    bootstrapIpv4 = "95.216.179.59";

    turnFqdn = "${config.passthru.hostName}.${config.passthru.domain}";
    signalFqdn = "signal-0.${config.passthru.domain}";
    bootstrapFqdn = "bootstrap-0.${config.passthru.domain}";
  };

  hostName = config.passthru.primaryIpv4;
  networking = {
    inherit (config.passthru) hostName domain;
  };

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [ "https://holochain-ci.cachix.org" ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  # FIXME: is there a better way to do this?
  environment.etc."systemd/network/10-cloud-init-eth0.network.d/00-floating-ips.conf".text = ''
    [Network]
    Address = ${config.passthru.signalIpv4}/32
    Address = ${config.passthru.bootstrapIpv4}/32
  '';

  system.stateVersion = "23.05";

  services.holochain-turn-server = {
    enable = true;
    url = config.passthru.turnFqdn;
    address = config.passthru.turnIpv4;
    username = "test";
    credential = "test";
    verbose = false;
    extraCoturnAttrs = {
      cli-ip = "127.0.0.1";
      cli-password = "$5$4c2b9a49c5e013ae$14f901c5f36d4c8d5cf0c7383ecb0f26b052134293152bd1191412641a20ddf5";
    };
  };

  services.tx5-signal-server = {
    enable = true;
    address = config.passthru.signalIpv4;
    port = 8443;
    tls-port = 443;
    url = config.passthru.signalFqdn;
    iceServers = [
      { urls = [ "stun:${config.services.holochain-turn-server.url}:80" ]; }
      {
        urls = [
          "turn:${config.services.holochain-turn-server.url}:80"
          "turn:${config.services.holochain-turn-server.url}:80?transport=tcp"
          "turns:${config.services.holochain-turn-server.url}:443?transport=tcp"
        ];

        inherit (config.services.holochain-turn-server) username credential;
      }
    ];
  };

  services.kitsune-bootstrap = {
    enable = true;
    address = config.passthru.bootstrapIpv4;
    port = 8444;
    tls-port = 443;
    url = config.passthru.bootstrapFqdn;
  };
}
