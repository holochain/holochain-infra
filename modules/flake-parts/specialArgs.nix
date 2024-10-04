{
  self,
  lib,
  inputs,
  ...
}:
{
  flake = {
    options.specialArgs = lib.mkOption { type = lib.types.attrs; };
    config.specialArgs = {
      inherit inputs self;

      infraDomain = self.nixosConfigurations.dweb-reverse-tls-proxy.config.passthru.domain;

      # TODO: manage secrets differently
      magicPaths = {
        githubRunnerHraTokenHostPath = "/var/secrets/github-runner/hra2.token";
        cachixToken = "/var/secrets/cachix.key";
      };
    };
  };
}
