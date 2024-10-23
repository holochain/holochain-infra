{
  # System independent arguments.
  self,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      # Arguments specific to the `perSystem` context.
      pkgs,
      self',
      ...
    }:
    {
      # system specific outputs like, apps, checks, packages

      packages =
        let
          system = pkgs.system;
          cranePkgs = inputs.craneNixpkgs.legacyPackages.${system};
          craneLib = inputs.crane.mkLib cranePkgs;

          postbuildstepperArgs =
            let
              pname = "postbuildstepper";
            in
            {
              inherit pname;

              src = self.inputs.nix-filter {
                root = self;
                # If no include is passed, it will include all the paths.
                include = [
                  # Include the "src" path relative to the root.
                  "applications/postbuildstepper"
                  # Include this specific path. The path must be under the root.
                  "Cargo.toml"
                  "Cargo.lock"
                  # Include all files with the .js extension
                ];
              };

              version = "alpha";

              cargoExtraArgs = "--bins";

              nativeBuildInputs = [ cranePkgs.pkg-config ];

              doCheck = true;
            };
          postbuildstepperDeps = lib.makeOverridable craneLib.buildDepsOnly postbuildstepperArgs;
        in
        {
          # TODO: remove this after the initial development testing phase
          inherit (pkgs) hello;

          postbuildstepper = lib.makeOverridable craneLib.buildPackage (
            postbuildstepperArgs // { cargoArtifacts = postbuildstepperDeps; }
          );

          postbuildstepper-test = pkgs.writeShellScriptBin "test" ''
            env \
              PROP_owners="['steveej']" \
              PROP_repository="https://github.com/Holo-Host/holo-nixpkgs" \
              PROP_project="Holo-Host/holo-nixpkgs" \
              PROP_attr="aarch64-linux.hello" \
              SECRET_cacheHoloHost2secret="testing-2:CoS7sAPcH1M+LD+D/fg9sc1V3uKk88VMHZ/MvAJHsuMSasehxxlUKNa0LUedGgFfA1wlRYF74BNcAldRxX2g8A==" \
              SECRET_awsSharedCredentialsFile="~/.aws/credentials" \
              PROP_out_path="${pkgs.hello}" \
              nix run .\#postbuildstepper
          '';
        };

      checks =
        let
          s3 = {
            bucket = "cache.holo.host";
            endpoint = "s3.wasabisys.com";
            key = "s3key";
            secret = "s3secret";
          };
        in
        {
          tests-postbuildstepper-integration = inputs.nixpkgs.lib.nixos.runTest {
            name = "postbuildstepper";

            imports = [ ];
            hostPkgs = pkgs; # the Nixpkgs package set used outside the VMs
            # defaults.services.foo.package = self'.packages.postbuildstepper;

            # One or more machines:
            nodes = {
              machine =
                { config, pkgs, ... }:

                {
                  networking.hosts = {
                    "127.0.0.1" = [
                      "cache.holo.host"
                      "s3.wasabisys.com"
                    ];
                  };

                  nix.settings.experimental-features = [
                    "nix-command"
                    "flakes"
                  ];

                  services.minio = {
                    enable = true;
                    browser = false;
                    listenAddress = "127.0.0.1:80";
                    rootCredentialsFile = pkgs.writeText "creds" ''
                      MINIO_ROOT_USER=${s3.key}
                      MINIO_ROOT_PASSWORD=${s3.secret}
                    '';
                  };
                };
            };

            testScript = ''
              machine.start()
              machine.wait_for_unit("minio.service")

              # TODO: insert credentials and pass them to the test as well
              machine.succeed("${lib.getExe self'.packages.postbuildstepper-test}", timeout = 10)
            '';

          };
        };
    };

  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
