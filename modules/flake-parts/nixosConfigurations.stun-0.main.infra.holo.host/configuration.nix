{
  config,
  inputs,
  self,
  pkgs,
  ...
}:
# https://console.hetzner.cloud/projects/1982619/servers/47741841/overview
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

    (self + "/modules/nixos/shared-monitoring-clients.nix")

    self.nixosModules.holochain-turn-server
  ];

  passthru = {
    fqdn = "${config.passthru.hostName}.${config.passthru.domain}";
    hostName = "stun-0";
    domain = "main.infra.holo.host";
    primaryIpv4 = "37.27.39.142";
  };

  hostName = config.passthru.primaryIpv4;
  networking = {
    inherit (config.passthru) hostName domain;
  };

  nix.settings.max-jobs = 8;

  nix.settings.substituters = [ "https://holochain-ci.cachix.org" ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-3:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "23.11";

  services.holochain-turn-server = {
    enable = true;
    url = config.passthru.fqdn;
    address = config.passthru.primaryIpv4;
    listening-port = null;
    nginx-http-port = 80;
    verbose = false;
    extraCoturnAttrs = {
      cli-ip = "127.0.0.1";
      cli-password = "$5$4c2b9a49c5e013ae$14f901c5f36d4c8d5cf0c7383ecb0f26b052134293152bd1191412641a20ddf5";
    };
    extraCoturnConfig = ''
      stun-only
    '';
    acme-staging = false;
  };
}
