{
  config,
  inputs,
  self,
  pkgs,
  ...
}:
# https://console.hetzner.cloud/projects/1982619/servers/47746862/overview
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
    self.nixosModules.ps1

    self.nixosModules.shared-monitoring-clients

    self.nixosModules.sbd-server
  ];

  passthru = {
    fqdn = "${config.passthru.hostName}.${config.passthru.domain}";

    domain = "main.infra.holo.host";
    hostName = "sbd-0";

    primaryIpv4 = "65.108.241.120";
  };

  networking = {
    inherit (config.passthru) hostName domain;
  };
  hostName = "${config.passthru.primaryIpv4}";

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [ "https://holochain-ci.cachix.org" ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-3:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "23.11";

  services.sbd-server = {
    enable = true;
    url = config.passthru.fqdn;
    address = config.passthru.primaryIpv4;
    tls-port = 443;
    trusted-ip-header = "cf-connecting-ip";

    # unlike the tx5-signal-server the sbd-server doesn't know about the STUN servers.
    # going forward its' going to be part of the conductor client config
    # "stun:${config.services.holochain-turn-server.url}:80"
  };
}
