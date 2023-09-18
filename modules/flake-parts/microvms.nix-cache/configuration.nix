{
  name,
  self,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    self.nixosModules.holo-users

    # inputs.sops-nix.nixosModules.sops

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
  ];
  networking.hostName = name;
  networking.firewall.enable = false;

  services.harmonia.enable = true;
  services.harmonia.settings.priority = 29;
  services.getty.autologinUser = "root";
  services.openssh.enable = true;

  systemd.services.download-holonix = {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    path = [pkgs.coreutils pkgs.nix pkgs.cacert pkgs.iputils];
    description = "download holonix into the local store";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "download-holonix" ''
        echo waiting for WAN connectivity..
        while true; do
          ping -c1 -w1 1.1.1.1 && {
            echo connected, continuing to download holonix
            break
          }
          sleep 1
        done

        nix build --keep-going -j0 \
          github:holochain/holochain#devShells.x86_64-linux.holonix \
          github:holochain/holochain#devShells.x86_64-darwin.holonix \
          github:holochain/holochain#devShells.aarch64-darwin.holonix \
          --override-input versions 'github:holochain/holochain?dir=versions/0_1'

        nix build --keep-going -j0 \
          github:holochain/holochain#packages.x86_64-linux.hc-scaffold \
          github:holochain/holochain#packages.x86_64-darwin.hc-scaffold \
          github:holochain/holochain#packages.aarch64-darwin.hc-scaffold

        # nix build --keep-going -j0 \
        #   github:holochain/holochain#devShells.x86_64-linux.holonix \
        #   github:holochain/holochain#devShells.x86_64-darwin.holonix \
        #   github:holochain/holochain#devShells.aarch64-darwin.holonix \
        #   --override-input versions 'github:holochain/holochain?dir=versions/0_2'
      '';
    };
  };
}
