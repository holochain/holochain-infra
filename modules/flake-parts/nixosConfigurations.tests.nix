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

    packages = {
      github-runner-multi-arch-test = let
        prefixName = "multi-arch-test";
        runnerServiceName = "github-runner-${prefixName}-0.service";
      in
        pkgs.testers.runNixOSTest {
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

              # copied from https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/github-runner.nix
              networking.hosts."127.0.0.1" = ["api.github.com"];
              systemd.services.dummy-github-com = {
                wantedBy = ["multi-user.target"];
                before = [runnerServiceName];
                script = "${pkgs.netcat}/bin/nc -Fl 443 | true && touch /tmp/registration-connect";
                serviceConfig.Restart = "always";
              };

              services.github-runner-multi-arch = {
                enable = true;
                countOffset = 0;
                count = lib.mkForce 1;
                namePrefix = lib.mkForce "multi-arch-test";
                tokenFile = builtins.toFile "tokenfile" "notsecret";
              };

              # sops.secrets.github-runners-token = {
              #   key = "gh_hra2_pat5";
              #   sopsFile = ../../../secrets/${config.networking.hostName}/secrets.yaml;
              # };
            };
          };
          testScript = {nodes, ...}: ''
            start_all()

            machine.wait_for_unit("dummy-github-com")
            machine.wait_for_unit("github-runner-${nodes.machine.config.services.github-runner-multi-arch.namePrefix}-${builtins.toString (nodes.machine.config.services.github-runner-multi-arch.count - 1)}")
            machine.wait_until_fails("github-runner-${nodes.machine.config.services.github-runner-multi-arch.namePrefix}-${builtins.toString (nodes.machine.config.services.github-runner-multi-arch.count - 1)}")
          '';
        };
    };
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
