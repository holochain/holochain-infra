/*
    iterating with:

    nomad job run ./nomad/commander.hcl
*/

job "commander" {

  constraint {
    attribute = "${meta.features}"
    operator  = "set_contains"
    value     = "ipv4-nat,nix"
  }

  constraint {
    attribute = "${meta.HOLO_NIXPKGS_CHANNEL}"
    operator  = "regexp"
    value     = ".*holo-nixpkgs/1694.*"
  }

  type = "sysbatch"

  task "command" {
    driver = "raw_exec"

    restart {
      attempts = 0
    }

    config {
      command = "/usr/bin/env"
      args = ["bash", "-c",
        <<-ENDOFSCRIPT
          set -e
          export NIX_PATH=nixpkgs=/nix/var/nix/profiles/per-user/root/channels/holo-nixpkgs/nixpkgs/
          nix-shell \
            -p nixos-rebuild \
            -p curl \
            -p sudo \
            --command "/run/wrappers/bin/sudo /usr/bin/env hpos-update 1691"

          # /run/wrappers/bin/sudo /usr/bin/env systemctl start holo-nixpkgs-auto-upgrade.service
        ENDOFSCRIPT
      ]
    }
  }
}
