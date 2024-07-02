{
  # System independent arguments.
  self,
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    pkgs,
    ...
  }: {
    # system specific outputs like, apps, checks, packages

    packages = {
      github-runner-multi-arch-test = pkgs.testers.runNixOSTest {
        name = "github-runner-multi-arch-test";
        node.specialArgs = {
          inherit self;
        };
        nodes = {
          runner = {config, ...}: {
            imports = [
              # self.inputs.sops-nix.nixosModules.sops
              self.nixosModules.github-runner-multi-arch
            ];

            config.services.github-runner-multi-arch = {
              enable = true;
              countOffset = 2;
              count = 2;
              namePrefix = "multi-arch-test";
              tokenFile = builtins.toFile "tokenfile" "notsecret";
            };

            # sops.secrets.github-runners-token = {
            #   key = "gh_hra2_pat5";
            #   sopsFile = ../../../secrets/${config.networking.hostName}/secrets.yaml;
            # };
          };
        };
        testScript = {nodes, ...}: ''
          machine.shell_interact()
          machine.wait_for_unit("github-runner-multi-arch-test-0.service")
          machine.wait_for_unit("github-runner-multi-arch-test-1.service")
        '';
      };
    };
  };
  flake = {
    # system independent outputs like nixosModules, nixosConfigurations, etc.

    # nixosConfigurations.example-host = ...
  };
}
