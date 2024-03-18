{
  writeShellScriptBin,
  jq,
  ...
}:
# TODO: make it real
writeShellScriptBin "tx5-signal-srv"
''
  while true; do ${jq}/bin/jq . $2; sleep 60; done
''
