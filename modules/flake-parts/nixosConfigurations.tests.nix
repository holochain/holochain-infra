{
  # System independent arguments.
  self,
  inputs,
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    pkgs,
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    packages = let
      prefixName = "multi-arch-test";
      runnerServiceName = "github-runner-${prefixName}-0.service";
      github-runner-multi-arch-test =
        pkgs.testers.runNixOSTest
        {
          name = "github-runner-multi-arch-test";
          node.specialArgs = {
            inherit self inputs;
          };
          nodes = {
            machine = {lib, ...}: {
              imports = [
                # self.inputs.sops-nix.nixosModules.sops
                # self.nixosModules.github-runner-multi-arch
                ./nixosConfigurations.linux-builder-01/configuration.nix
              ];

              services.github-runner-multi-arch = {
                enable = true;
                countOffset = 0;
                count = lib.mkForce 1;
                namePrefix = lib.mkForce "multi-arch-test";
                url = "https://github.com/steveej/empty";

                # TODO: pass a minimal-permissioned github token that can indeed create a new runner
                tokenFile = builtins.toFile "tokenfile" "***";
              };

              # sops.secrets.github-runners-token = {
              #   key = "gh_hra2_pat5";
              #   sopsFile = ../../../secrets/${config.networking.hostName}/secrets.yaml;
              # };
            };
          };
          testScript = {nodes, ...}: ''
            start_all()

            machine.succeed("ping -c1 github.com")

            machine.wait_for_unit("github-runner-${nodes.machine.config.services.github-runner-multi-arch.namePrefix}-${builtins.toString (nodes.machine.config.services.github-runner-multi-arch.count - 1)}")

            # TODO: parse the log and assert
            # Runner successfully added
          '';
        };
    in {
      inherit github-runner-multi-arch-test;

      # needs to be run like so currently:
      # NIX_CONFIG="sandbox = relaxed" sudo -E nix build .\#github-runner-multi-arch-test-online
      github-runner-multi-arch-test-online = github-runner-multi-arch-test.config.rawTestDerivation.overrideAttrs (_: {__noChroot = true;});
    };
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
