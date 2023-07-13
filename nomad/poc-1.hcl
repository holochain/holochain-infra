/*
    poc-1 demonstrating a client-server relationship
*/

job "poc-1" {
    type = "batch"

    group "servers" {
        network {
            port "iperf3" {}
        }

        task "iperf3-server" {
            constraint {
                attribute = "${meta.features}"
                operator = "set_contains"
                value = "ipv4-public,nix"
            }

            service {
                provider = "nomad"
                name = "iperf3"
                port = "iperf3"

                // GOTCHA: this check triggers an error on the iperf3 server
                // check {
                //     type = "tcp"
                //     port = "iperf3"
                //     interval = "10s"
                //     timeout = "1s"
                // }
            }


            driver = "raw_exec"
            config {
                command = "/usr/bin/env"
                args = ["bash", "-c", 
                    <<ENDOFSCRIPT
                    set -xe
                    env
                    while true; do
                        nix run nixpkgs#iperf3 -- --port ''${NOMAD_PORT_iperf3} --server
                    done
                    ENDOFSCRIPT
                ]
            }
        }
    }

    task "iperf3-client" {
        constraint {
            attribute = "${meta.features}"
            operator = "set_contains"
            value = "ipv4-nat,nix"
        }

        template {
            data = <<EOH
                {{ range nomadService "iperf3" }}
                IPERF3_HOST="{{ .Address }}"
                IPERF3_PORT="{{ .Port }}"
                {{ end }}
                EOH
            destination = "local/env.txt"
            env         = true
        }

        driver = "raw_exec"
        config {
            command = "/usr/bin/env"
            args = ["bash", "-c", 
                <<ENDOFSCRIPT
                set -xe
                nix run nixpkgs#iperf3 -- --port $IPERF3_PORT --client $IPERF3_HOST
                ENDOFSCRIPT
            ]
        }
    }
    
}
