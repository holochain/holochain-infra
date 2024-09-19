{
  config,
  inputs,
  self,
  pkgs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    self.nixosModules.hardware-hetzner-cloud-cpx

    inputs.sops-nix.nixosModules.sops

    self.nixosModules.holo-users
    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
  ];

  networking.hostName = config.passthru.hostName; # Define your hostname.

  hostName = "${config.passthru.hostName}.${(builtins.elemAt (builtins.attrValues self.nixosConfigurations.dweb-reverse-tls-proxy.config.services.bind.zones) 0).name}";

  nix.settings.max-jobs = 3;

  nix.settings.substituters = [
    "https://holochain-ci.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "holochain-ci.cachix.org-2:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
  ];

  system.stateVersion = "24.05";

  passthru = {
    hostName = "monitoring-0";
    primaryIpv4 = "135.181.110.69";
  };
}
