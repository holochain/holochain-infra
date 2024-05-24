{
  stdenv,
  closureInfo,
  pixz,
  # The files and directories to be placed in the directory.
  # This is a list of attribute sets {source, target} where `source'
  # is the file system object (regular file or directory) to be
  # grafted in the file system at path `target'.
  contents,
  # In addition to `contents', the closure of the store paths listed
  # in `packages' are also placed in the Nix store of the tarball.  This is
  # a list of attribute sets {object, symlink} where `object' if a
  # store path whose closure will be copied, and `symlink' is a
  # symlink to `object' that will be added to the tarball.
  storeContents ? [],
  # Extra commands to be executed before archiving files
  extraCommands ? "",
  # extra inputs
  extraInputs ? [],
}: let
  symlinks = map (x: x.symlink) storeContents;
  objects = map (x: x.object) storeContents;
in
  stdenv.mkDerivation {
    name = "system-directory";
    builder = ./make-system-directory.sh;
    nativeBuildInputs = extraInputs;

    inherit extraCommands;

    # !!! should use XML.
    sources = map (x: x.source) contents;
    targets = map (x: x.target) contents;

    # !!! should use XML.
    inherit symlinks objects;

    closureInfo = closureInfo {
      rootPaths = objects;
    };
  }
