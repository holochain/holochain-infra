/*
    poc-2: run a cargo test that has a server and a client role

    - a public reachable node runs the server role
    - defined number of nat'ed nodes run the client roles, getting the server's IP and port via environment variables

    - improvement TODOs:
        - add prestart tasks that only compile the binaries
            - server
            - clients
        - start run the clients when the server is ready
*/

variables {
    GIT_URL = "https://github.com/steveej-forks/holochain.git"
    GIT_BRANCH = "pr_distributed-test-poc"
    agents = 5
    agents_readiness_timeout_secs = 720
}

job "poc-2" {
    type = "batch"

    group "server" {
        network {
            port "holochainTestRemoteV1" {}
        }

        task "test-remotev1-distributed-server" {
            env {
                GIT_URL = "${var.GIT_URL}"
                GIT_BRANCH = "${var.GIT_BRANCH}"
            }

            constraint {
                attribute = "${meta.features}"
                operator = "set_contains"
                value = "ipv4-public,nix"
            }

            service {
                provider = "nomad"
                name = "holochainTestRemoteV1"
                port = "holochainTestRemoteV1"

                // check {
                //     name     = "remote_v1_server_up"
                //     type     = "tcp"
                //     port     = "holochainTestRemoteV1"
                //     interval = "10s"
                //     timeout  = "2s"
                // }
            }

            template {
                data = file("nomad/poc-2/init.sh")
                destination = "local/init.sh"
                perms = "555"
            }

            driver = "raw_exec"
            config {
                command = "/usr/bin/env"
                args = ["bash", "-c",
                    <<ENDOFSCRIPT
                    set -xeu

                    source local/init.sh
                    env

                    export TEST_SHARED_VALUES_REMOTEV1_ROLE="server"
                    export TEST_SHARED_VALUES_REMOTEV1_URL="ws://${NOMAD_HOST_IP_holochainTestRemoteV1}:${NOMAD_HOST_PORT_holochainTestRemoteV1}"

                    nix develop -vL .#coreDev --command \
                        cargo nextest run --locked -p holochain_test_utils --no-capture --features slow_tests --status-level=pass --retries=99999999 discovery_distributed
                    ENDOFSCRIPT
                ]
            }
        }

    }

    group "clients" {
        count = var.agents

        restart {
            attempts = 0
            mode = "fail"
        }

        constraint {
            distinct_hosts = true
        }

        task "test-remotev1-distributed-clients" {
            constraint {
                attribute = "${meta.features}"
                operator = "set_contains"
                value = "ipv4-nat,nix"
            }

            env {
                GIT_URL = "${var.GIT_URL}"
                GIT_BRANCH = "${var.GIT_BRANCH}"
            }

            template {
                data = <<-EOH
                    {{ range nomadService "holochainTestRemoteV1" }}
                    TEST_SHARED_VALUES_REMOTEV1_ROLE="client"
                    TEST_SHARED_VALUES_REMOTEV1_URL="ws://{{ .Address }}:{{ .Port }}"
                    TEST_AGENT_READINESS_REQUIRED_AGENTS=${var.agents}
                    TEST_AGENT_READINESS_TIMEOUT_SECS=${var.agents_readiness_timeout_secs}
                    {{ end }}
                    EOH
                destination = "local/env.txt"
                env         = true
            }

            template {
                data = file("nomad/poc-2/init.sh")
                destination = "local/init.sh"
                perms = "555"
            }

            driver = "raw_exec"
            config {
                command = "/usr/bin/env"
                args = ["bash", "-c",
                    <<ENDOFSCRIPT
                    set -xe

                    source local/init.sh
                    env

                    nix develop -vL .#coreDev --command \
                        cargo nextest run --locked -p holochain_test_utils --no-capture --features slow_tests --status-level=pass --retries=0 discovery_distributed
                    ENDOFSCRIPT
                ]
            }
        }
    }
}
