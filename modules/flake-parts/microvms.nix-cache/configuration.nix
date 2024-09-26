{
  name,
  self,
  pkgs,
  ...
}:
let
  storeDumpPath = "/nix/.rw-store/db.dump";
  svcName = "populate-cache";
in
{
  imports = [
    self.nixosModules.holo-users

    # inputs.sops-nix.nixosModules.sops

    ../../nixos/shared.nix
    ../../nixos/shared-nix-settings.nix
  ];
  networking.hostName = name;
  networking.firewall.enable = false;

  services.harmonia = {
    enable = true;
    settings.priority = 29;
    signKeyPath = "/nix/.rw-store/harmonia.secret";
  };
  services.getty.autologinUser = "root";
  services.openssh.enable = true;

  users.extraUsers.root.openssh.authorizedKeys.keys = [
    # "ssh-rsa AAAAB3NzaC1yc2etc/etc/etcjwrsh8e596z6J0l7 example@host"
  ];

  environment.systemPackages = [
    pkgs.htop
    pkgs.glances
  ];

  systemd.services.${svcName} = {
    wantedBy = [ "multi-user.target" ];
    partOf = [ "nix-cache.target" ];
    requires = [ "nix-store-load-db.service" ];
    after = [ "network.target" ];
    path = [
      pkgs.coreutils
      pkgs.nix
      pkgs.cacert
      pkgs.iputils
      pkgs.gitFull
    ];
    description = "populating nix cache";
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      User = svcName;
      WorkingDirectory = "%C/${svcName}";
      CacheDirectory = svcName;
    };

    script =
      let
        mkPopulateCacheSnippet =
          { arch }:
          ''
            time nix build -L --refresh --keep-going -j0 \
              --out-link result-${arch}-0 \
              github:holochain/holochain#packages.${arch}.hc-scaffold

            time nix build -L --refresh --keep-going -j0 \
              --out-link result-${arch}-1 \
              --override-input versions 'github:holochain/holochain?dir=versions/0_1' \
              github:holochain/holochain#packages.${arch}.hc-scaffold

            time nix build -L --refresh --keep-going -j0 \
              --out-link result-${arch}-2 \
              --override-input versions 'github:holochain/holochain?dir=versions/0_2' \
              github:holochain/holochain#packages.${arch}.hc-scaffold

            time nix build -L --refresh --keep-going -j0 \
              --out-link result-${arch}-3 \
              --override-input versions 'github:holochain/holochain?dir=versions/weekly' \
              github:holochain/holochain#packages.${arch}.hc-scaffold


            time nix develop --build -L --refresh --keep-going -j0 \
              --profile result-${arch}-4 \
              --override-input versions 'github:holochain/holochain?dir=versions/0_1' \
              github:holochain/holochain#devShells.${arch}.holonix
            time nix develop --build -L --refresh --keep-going -j0 \
              --profile result-${arch}-5 \
              --override-input versions 'github:holochain/holochain?dir=versions/0_2' \
              github:holochain/holochain#devShells.${arch}.holonix
            time nix develop --build -L --refresh --keep-going -j0 \
              --profile result-${arch}-6 \
              --override-input versions 'github:holochain/holochain?dir=versions/weekly' \
              github:holochain/holochain#devShells.${arch}.holonix
          '';
      in
      ''
        echo waiting for WAN connectivity..
        while true; do
          ping -c1 -w1 1.1.1.1 && {
            echo connected, poceeding to populate cache
            break
          }
          sleep 1
        done

        set -x
        export HOME=$(pwd)

        while true;
          do

          # we keep the previous result links around so that garbage-collection doesn't clean up their data
          mkdir -p previous_results
          find -type l -name "result*" -exec mv {} previous_results/ \;

          # don't bail on failures, keep going with best effort
          set +e
      ''
      + mkPopulateCacheSnippet { arch = "x86_64-linux"; }
      + mkPopulateCacheSnippet { arch = "x86_64-darwin"; }
      + mkPopulateCacheSnippet { arch = "aarch64-darwin"; }
      + ''
          set -e

          # it's okay to garbage-collect the previous results now
          rm -rf previous_results
          sleep 360
        done
      '';
  };

  # due to a limitation in microvm.nix we manually dump and load the nix-store db.
  # if we don't do this the store paths will be forgotten.
  systemd.services.nix-store-load-db = {
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];
    path = [ pkgs.nix ];
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
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.nix
      pkgs.coreutils
    ];
    unitConfig.RequiresMountsFor = [ "/nix/.rw-store" ];
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
