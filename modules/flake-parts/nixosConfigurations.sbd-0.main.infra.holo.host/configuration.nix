{
  config,
  inputs,
  self,
  pkgs,
  ...
}:
let
  # https://console.hetzner.cloud/projects/1982619/servers/47746862/overview
  hostName = "sbd-0";
  domain = "main.infra.holo.host";
  ipv4 = "65.108.241.120";
  fqdn = "${config.networking.hostName}.${config.networking.domain}";
in
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

    (self + "/modules/nixos/shared-monitoring-clients.nix")

    self.nixosModules.sbd-server
  ];

  networking = {
    inherit hostName domain;
  };

  hostName = ipv4;

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [ "https://holochain-ci.cachix.org" ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-3:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "23.11";

  services.sbd-server = {
    enable = true;
    url = fqdn;
    address = ipv4;
    tls-port = 443;
    trusted-ip-header = "cf-connecting-ip";

    # unlike the tx5-signal-server the sbd-server doesn't know about the STUN servers.
    # going forward its' going to be part of the conductor client config
    # "stun:${config.services.holochain-turn-server.url}:80"
  };
}
