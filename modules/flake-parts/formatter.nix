{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # define formatter used by `nix fmt`
      formatter = pkgs.alejandra;
    };
}
