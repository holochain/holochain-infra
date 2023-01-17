{ lib, ... }: {
  options.magicPaths = lib.mkOption {type = lib.types.attrs;};
  config.magicPaths = {
    githubRunnerHraTokenHostPath = "/var/secrets/github-runner/hra2.token";
    githubRunnerHraTokenMountPoint = "/secrets/github-runner/token";
  };
}
