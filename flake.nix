{
  description = "The new, performant, and simplified version of Holochain on Rust (sometimes called Holochain RSM for Refactored State Model) ";

  inputs = {
    nixpkgs.follows = "nixpkgs-24-05";
    nixpkgs-23-11 = {url = "github:nixos/nixpkgs/nixos-23.11";};
    nixpkgs-24-05 = {url = "github:nixos/nixpkgs/nixos-24.05";};
    nixpkgsNix.follows = "nixpkgs-24-05";
    nixpkgsGithubActionRunners = {url = "github:nixos/nixpkgs/nixos-unstable";};
    nixpkgsUnstable = {url = "github:nixos/nixpkgs/nixos-unstable";};
    nixpkgsMaster = {url = "github:nixos/nixpkgs/master";};

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    srvos.url = "github:numtide/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:numtide/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    # nix darwin
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home manager
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # secret management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # have the latest rust version available
    craneNixpkgs = {url = "github:nixos/nixpkgs/nixos-unstable";};
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "craneNixpkgs";
    };

    keys_steveej = {
      url = "https://github.com/steveej.keys";
      flake = false;
    };
    keys_jost-s = {
      url = "https://github.com/jost-s.keys";
      flake = false;
    };

    # hash mismatch 2024/02/29
    # keys_maackle = {
    #   url = "https://github.com/maackle.keys";
    #   flake = false;
    # };

    # hash mismatch 20230821
    # keys_neonphog = {
    #   url = "https://github.com/neonphog.keys";
    #   flake = false;
    # };

    # TODO: re-enable once the change is verified
    # keys_thedavidmeister = {
    #   url = "https://github.com/thedavidmeister.keys";
    #   flake = false;
    # };

    keys_thetasinner = {
      url = "https://github.com/ThetaSinner.keys";
      flake = false;
    };

    # hash mismatch 20240710
    # keys_zippy = {
    #   url = "https://github.com/zippy.keys";
    #   flake = false;
    # };

    keys_artbrock = {
      url = "https://github.com/artbrock.keys";
      flake = false;
    };

    keys_r-vdp = {
      url = "https://git.sr.ht/~r-vdp/nixos-config/blob/main/users/ramses/authorized_keys";
      flake = false;
    };

    cachix_for_watch_store.url = "github:cachix/cachix/v1.5";

    tx5.url = "github:holochain/tx5/tx5-signal-srv-v0.0.8-alpha";
    tx5.flake = false;
    sbd.url = "github:holochain/sbd/sbd-server-v0.0.4-alpha";
    sbd.flake = false;

    holochain-versions.url = "github:holochain/holochain?dir=versions/weekly";
    holochain = {
      url = "github:holochain/holochain";
      inputs.versions.follows = "holochain-versions";
    };

    coturn = {
      flake = false;
      url = "github:steveej-forks/coturn/debug-cli-login";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    threefold-rfs = {
      url = "github:threefoldtech/rfs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.crane.follows = "crane";
    };

    holoNixpkgs.url = "https://hydra.holo.host/channel/custom/holo-nixpkgs/2112/holo-nixpkgs/nixexprs.tar.xz";

    nixpkgsPulumi.url = "github:steveej-forks/nixpkgs/pulumi-version-bump";

    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      # auto import all nix code from `./modules`
      imports =
        map (m: "${./.}/modules/flake-parts/${m}")
        (builtins.attrNames (builtins.readDir ./modules/flake-parts));

      systems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        lib,
        system,
        ...
      }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.
        devShells.default = let
          nomadAddr = "https://${self.nixosConfigurations.dweb-reverse-tls-proxy.config.hostName}:4646";
          nomadCaCert = ./secrets/nomad/admin/nomad-agent-ca.pem;
          nomadClientCert = ./secrets/nomad/cli/global-cli-nomad.pem;

          pkgsUnstable = inputs'.nixpkgsUnstable.legacyPackages;
          pkgsPulumi = inputs'.nixpkgsPulumi.legacyPackages;
        in
          pkgs.mkShell {
            packages =
              [
                self'.formatter

                pkgs.yq-go

                inputs'.nixos-anywhere.packages.default

                inputs'.sops-nix.packages.default
                pkgs.ssh-to-age
                pkgs.age
                pkgs.age-plugin-yubikey
                pkgs.sops

                # self'.packages.nomad

                (pkgs.writeShellScriptBin "nomad-ui-proxy" (let
                  caddyfile = pkgs.writeText "caddyfile" ''
                    {
                      auto_https off
                      http_port 2016
                    }

                    localhost:2016 {
                      reverse_proxy ${nomadAddr} {
                        transport http {
                          tls_trusted_ca_certs ${nomadCaCert}
                          tls_client_auth ${nomadClientCert} {$NOMAD_CLIENT_KEY}
                        }
                      }
                    }
                  '';
                in ''
                  ${pkgs.caddy}/bin/caddy run --adapter caddyfile --config ${caddyfile}
                ''))
                pkgs.caddy

                inputs'.threefold-rfs.packages.default
                pkgs.minio-client

                pkgs.jq
                pkgsPulumi.pulumictl
                (pkgsPulumi.pulumi.withPackages (pulumiPackages:
                  with pulumiPackages; [
                    pulumi-language-go
                    pulumi-command
                  ]))
                pkgs.go_1_21
              ]
              ++ (
                let
                  zosCmds = builtins.filter (pkg: null != (builtins.match "^zos-.*" pkg.name)) (builtins.attrValues self'.packages);
                in
                  zosCmds
                  ++ (lib.lists.flatten (builtins.map (cmd: cmd.nativeBuildInputs or []) zosCmds))
                  ++ (lib.lists.flatten (builtins.map (cmd: cmd.buildInputs or []) zosCmds))
                  ++ (lib.lists.flatten (builtins.map (cmd: cmd.runtimeInputs or []) zosCmds))
              );

            NOMAD_ADDR = nomadAddr;
            NOMAD_CACERT = nomadCaCert;
            NOMAD_CLIENT_CERT = nomadClientCert;

            shellHook = let
              devMinioOsConfig = self.nixosConfigurations.x64-linux-dev-01.config;
            in
              ''
                if sops -d secrets/nomad/cli/keys.yaml 2>&1 >/dev/null; then
                  REPO_SECRETS_DIR="''${HOME:?}/.holochain-infra-secrets"
                  mkdir -p ''${REPO_SECRETS_DIR}
                  chmod 700 ''${REPO_SECRETS_DIR}
                  export NOMAD_CLIENT_KEY="''${REPO_SECRETS_DIR}/global-cli-nomad-key";
                  sops -d secrets/nomad/cli/keys.yaml | yq '.global-cli-nomad-key' > ''${NOMAD_CLIENT_KEY:?}
                fi
              ''
              + (let
                minioUserPass = ''''${MINIO_ROOT_USER}:''${MINIO_ROOT_PASSWORD}'';
                minioDevHost = devMinioOsConfig.services.devMinio.s3Domain + ":443";
                minioDevLocalHost = "127.0.0.1:${builtins.toString devMinioOsConfig.services.devMinio.listenPort}";
                minioRegion = devMinioOsConfig.services.devMinio.region;
              in ''
                if sops -d secrets/minio/server.yaml 2>&1 >/dev/null; then
                  source <(sops -d secrets/minio/server.yaml | yq '.minio_root_credentials')

                  export MC_HOST_devminio_local="http://${minioUserPass}@${minioDevLocalHost}";
                  export MC_HOST_devminio="https://${minioUserPass}@${minioDevHost}"

                  export RFS_HOST_devminio_region="${minioRegion}"
                  export RFS_HOST_devminio_local="s3://${minioUserPass}@${minioDevLocalHost}"
                  export RFS_HOST_devminio="s3s://${minioUserPass}@${minioDevHost}"
                fi
              '');
          };

        packages =
          {
            # nomad = pkgs.nomad_1_6;

            nixos-anywhere = inputs'.nixos-anywhere.packages.default;
          }
          // (
            let
              mkOsConfigCheck = osConfigs: let
                filteredBySystem =
                  lib.filterAttrs (
                    key: value:
                      (value.pkgs.system == system)
                      # needs private repos
                      && (key != "tfgrid-hpos")
                  )
                  osConfigs;
                asStrings =
                  lib.mapAttrsToList (
                    key: value:
                      builtins.trace "evaluating ${key} (${value.pkgs.system})..."
                      "ln -s ${value.config.system.build.toplevel} $out/${key}"
                  )
                  filteredBySystem;
              in
                pkgs.stdenv.mkDerivation {
                  name = "check-osconfigurations";
                  phases = "installPhase";
                  installPhase = "mkdir $out;" + builtins.concatStringsSep "\n" asStrings;
                };
            in {
              build-os-configurations =
                if pkgs.stdenv.isLinux
                then
                  mkOsConfigCheck (builtins.removeAttrs self.nixosConfigurations [
                    # too big for current CI structure and rarely used
                    "vm-nixcache"
                  ])
                else if pkgs.stdenv.isDarwin
                then mkOsConfigCheck self.darwinConfigurations
                else throw "unexpected case";
            }
          );
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
      };
    };
}
