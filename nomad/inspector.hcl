/*
    this job will run on all nodes as it's of type 'system'

    iterating with:

    nomad job run ./nomad/inspector.hcl
*/

job "inspector" {
  constraint {
    attribute = "${meta.features}"
    operator  = "set_contains"
    value     = "ipv4-nat,nix"
  }

  constraint {
    attribute = "${meta.HOLO_NIXPKGS_REVISION}"
    operator  = "is_set"
  }

  type = "system"

  task "sleeper" {
    driver = "raw_exec"

    config {
      command = "/usr/bin/env"
      args = ["bash", "-c",
        <<-ENDOFSCRIPT
          while true; do
            echo [${meta.HOLO_ZEROTIER_IP}] $(uptime)
            sleep 360
          done
        ENDOFSCRIPT
      ]
    }
  }
}
