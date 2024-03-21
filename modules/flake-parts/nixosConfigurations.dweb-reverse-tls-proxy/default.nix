{
  self,
  lib,
  inputs,
  ...
}: {
  flake.nixosConfigurations.dweb-reverse-tls-proxy = inputs.nixpkgs.lib.nixosSystem rec {
    modules = [./configuration.nix];
    system = "x86_64-linux";
    specialArgs = self.specialArgs;
  };
}
