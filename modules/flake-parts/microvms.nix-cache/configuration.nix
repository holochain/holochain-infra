{
  name,
  self,
  config,
  lib,
  pkgs,
  ...
}: let
  storeDumpPath = "/nix/.rw-store/db.dump";
in {
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

  systemd.services.populate-cache = {
    wantedBy = ["multi-user.target"];
    partOf = ["nix-cache.target"];
    requires = ["nix-store-load-db.service"];
    after = ["network.target"];
    path = [pkgs.coreutils pkgs.nix pkgs.cacert pkgs.iputils pkgs.gitFull];
    description = "populating nix cache";
    serviceConfig = {
      Type = "simple";
    };

    script = let
      mkPopulateCacheSnippet = {arch}: ''
        time nix build -L --refresh --keep-going -j0 \
          --override-input versions 'github:holochain/holochain?dir=versions/0_1' \
          github:holochain/holochain#devShells.${arch}.holonix

        time tnix build -L --refresh --keep-going -j0 \
          github:holochain/holochain#packages.${arch}.hc-scaffold

        time nix build -L --refresh --keep-going -j0 \
          --override-input versions 'github:holochain/holochain?dir=versions/0_2' \
          github:holochain/holochain#devShells.${arch}.holonix
      '';
    in
      ''
        echo waiting for WAN connectivity..
        while true; do
          ping -c1 -w1 1.1.1.1 && {
            echo connected, continuing to populate cache
            break
          }
          sleep 1
        done

        while true;
          do
          set -x
      ''
      + mkPopulateCacheSnippet {arch = "x86_64-linux";}
      + mkPopulateCacheSnippet {arch = "x86_64-darwin";}
      + mkPopulateCacheSnippet {arch = "aarch64-darwin";}
      + ''
          sleep 60
        done
      '';
  };

  # due to a limitation in microvm.nix we manually dump and load the nix-store db.
  # if we don't do this the store paths will be forgotten.
  systemd.services.nix-store-load-db = {
    wantedBy = ["multi-user.target"];
    before = ["network.target"];
    path = [pkgs.nix];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -x
      if [[ -f ${storeDumpPath} ]]; then
        set -e
        nix-store --load-db < ${storeDumpPath}
        nix-store --verify --repair
      else
        echo WARNING: could not find db.dump
      fi
    '';
  };

  systemd.services.nix-store-dump-db = {
    wantedBy = ["multi-user.target"];
    path = [pkgs.nix pkgs.coreutils];
    unitConfig.RequiresMountsFor = ["/nix/.rw-store"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStop = pkgs.writeShellScript "nix-store-dump-db" ''
        set -xe

        sync

        nix-store --verify --repair
        nix-store --dump-db > ${storeDumpPath}.new
        mv --backup=numbered ${storeDumpPath}{.new,}
      '';
    };
  };
}
