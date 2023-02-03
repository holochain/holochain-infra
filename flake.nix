{
  description = "The new, performant, and simplified version of Holochain on Rust (sometimes called Holochain RSM for Refactored State Model) ";

  inputs = rec {
    nixpkgs = {url = "github:nixos/nixpkgs/release-22.11";};

    cachix = {
      url = "github:cachix/cachix/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix darwin
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    keys_steveej = {
      url = "https://github.com/steveej.keys";
      flake = false;
    };
    keys_jost-s = {
      url = "https://github.com/jost-s.keys";
      flake = false;
    };
    keys_maackle = {
      url = "https://github.com/maackle.keys";
      flake = false;
    };
    keys_neonphog = {
      url = "https://github.com/neonphog.keys";
      flake = false;
    };
    keys_thedavidmeister = {
      url = "https://github.com/thedavidmeister.keys";
      flake = false;
    };
    keys_zippy = {
      url = "https://github.com/zippy.keys";
      flake = false;
    };
    keys_davhau = {
      url = "https://github.com/davhau.keys";
      flake = false;
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      # auto import all nix code from `./modules`
      imports =
        map (m: "${./.}/modules/${m}")
        (builtins.attrNames (builtins.readDir ./modules));

      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem = {
        config,
        self',
        inputs',
        ...
      }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
      };
    };
}
