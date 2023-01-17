{ self, lib, ... }: {
  flake.modules.darwin.github-runners = ./darwinModule;
}
