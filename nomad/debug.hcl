/*
    file to initially debug and learn.

    iterating with:

    nomad job stop -purge debug
    nomad job run ./nomad/debug.hcl
    nomad status -verbose debug | rg -o '([^ ]+).*holochain-version' -r '$1' | xargs -L1 nomad logs -f
*/

job "debug" {
    constraint {
        attribute = "${meta.features}"
        operator = "set_contains"
        value = "nix"
    }

    type = "batch"

    task "holochain-version" {
        driver = "raw_exec"
        config {
            command = "/usr/bin/env"
            args = ["bash", "-c", 
                <<ENDOFSCRIPT
                set -xe

                rm -rf holochain
                git clone https://github.com/holochain/holochain.git --depth 1 --single-branch --branch develop
                cd holochain
                nix run .#holochain \
                    --override-input holochain . \
                    --override-input versions ./versions/weekly \
                    -- --version
                ENDOFSCRIPT
            ]
        }
    }

    // task "nix-version" {
    //     driver = "raw_exec"
    //     config {
    //         command = "/usr/bin/env"
    //         args = ["nix", "--version"]
    //     }
    // }

    // task "inspect-environment" {
    //     driver = "raw_exec"
    //     config {
    //         command = "/usr/bin/env"
    //     }
    // }

    // task "inspect-path" {
    //     driver = "raw_exec"
    //     config {
    //         command = "/usr/bin/env"
    //         args = ["echo", "$PATH"]
    //     }
    // }
}