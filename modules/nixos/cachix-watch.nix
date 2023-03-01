{
  config,
  lib,
  magicPaths,
  ...
}: {
  services.cachix-watch-store = {
    enable = true;
    cacheName = "holochain-ci";
    cachixTokenFile = magicPaths.cachixToken;
    jobs = 4;
    compressionLevel = 3;
    verbose = true;
  };
}
