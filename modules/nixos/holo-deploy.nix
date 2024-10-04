{
  self,
  lib,
  config,
  ...
}:

{
  options = {
    deployUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "The user used for deployment via ssh";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "IP addres or host name to connect to the host";
    };

    deploySkipAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    environment.etc."nix/sourceInfo.json" = {
      enable = true;
      text = builtins.toJSON (builtins.removeAttrs self.sourceInfo [ "outPath" ]);
    };

    environment.etc."nix/source" = {
      enable = true;
      text = self.sourceInfo.outPath;
    };
  };
}
