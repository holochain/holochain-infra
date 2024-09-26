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

      # TODO: manage secrets differently
      magicPaths = {
        githubRunnerHraTokenHostPath = "/var/secrets/github-runner/hra2.token";
        cachixToken = "/var/secrets/cachix.key";
      };
    };
  };
}
