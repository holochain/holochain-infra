{
  # System independent arguments.
  lib,
  inputs,
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    self',
    pkgs,
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    packages = let
      system = pkgs.system;
      craneLib = inputs.crane.lib.${system};
      cranePkgs = inputs.crane.inputs.nixpkgs.legacyPackages.${system};
    in {
      tx5 = craneLib.buildPackage {
        pname = "tx5";
        src = inputs.tx5;
        version = inputs.tx5.rev;
        cargoExtraArgs = "--examples --bins";
        nativeBuildInputs = [
          cranePkgs.perl
          cranePkgs.pkg-config
          cranePkgs.go
        ];

        doCheck = false;
      };

      tx5-signal-srv = pkgs.runCommandNoCC "tx5-signal-srv" {} ''
        mkdir -p $out/bin
        cp ${self'.packages.tx5}/bin/tx5-signal-srv $out/bin/
      '';
    };
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
