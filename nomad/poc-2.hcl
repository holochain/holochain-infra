/*
    poc-2: distributed holochain gossip test

    - public reachable node runs the bootstrap and turn servers
    - nat'ed conductors are configured to use these public services
    - a simple happ generates data and ensures it is getting data back from others
*/

job "poc-2" {
    type = "batch"

    group "servers" {
        network {
            port "holochainBootstrap" {}
            port "holochainSignal" {}
        }

        task "holochain-services" {
            constraint {
                attribute = "${meta.features}"
                operator = "set_contains"
                value = "ipv4-public,nix"
            }

            service {
                provider = "nomad"
                name = "holochainBootstrap"
                port = "holochainBootstrap"
            }

            service {
                provider = "nomad"
                name = "holochainSignal"
                port = "holochainSignal"
            }

            driver = "raw_exec"
            config {
                command = "/usr/bin/env"
                args = ["bash", "-c", 
                <<ENDOFSCRIPT
                set -xe
                env

                # git ls-remote https://github.com/holochain/holochain.git --branch develop

                nix shell -vL github:holochain/holochain#holochain \
                    --override-input versions 'github:holochain/holochain?dir=versions/weekly' \
                    --override-input versions/holochain 'github:holochain/holochain/a585a619d68bd47d2e995a773cdf76dea08fdca3' \
                    --command \
                    hc-run-local-services \
                    --help

                export RUST_LOG=debug
                nix shell -vL github:holochain/holochain#holochain \
                    --override-input versions 'github:holochain/holochain?dir=versions/weekly' \
                    --override-input versions/holochain 'github:holochain/holochain/a585a619d68bd47d2e995a773cdf76dea08fdca3' \
                    --command \
                    hc-run-local-services \
                        --bootstrap-interface 0.0.0.0 \
                        --bootstrap-port ''${NOMAD_PORT_holochainBootstrap} \
                        --signal-interfaces 0.0.0.0 \
                        --signal-port ''${NOMAD_PORT_holochainSignal}
                ENDOFSCRIPT
                ]
            }
        }
    }



    task "holochain-conductor" {
        constraint {
            attribute = "${meta.features}"
            operator = "set_contains"
            value = "ipv4-nat,nix"
        }

        template {
            data = <<EOH
                {{ range nomadService "holochain-boostrap" }}
                BOOTSTRAP_HOST="{{ .Address }}"
                BOOTSTRAP_PORT="{{ .Port }}"
                {{ end }}
                {{ range nomadService "holochain-signal" }}
                SIGNAL_HOST="{{ .Address }}"
                SIGNAL_PORT="{{ .Port }}"
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
                nix shell -vL github:holochain/holochain#holochain \
                    --override-input versions 'github:holochain/holochain?dir=versions/weekly' \
                    --override-input versions/holochain 'github:holochain/holochain/a585a619d68bd47d2e995a773cdf76dea08fdca3' \
                    --command \
                    holochain \
                    --help
                ENDOFSCRIPT

                <<ENDOFCFG
                ---
                environment_path: /path/to/env
                signing_service_uri: ws://localhost:9001
                encryption_service_uri: ws://localhost:9002
                decryption_service_uri: ws://localhost:9003

                keystore:
                type: lair_server_in_proc

                dpki:
                instance_id: some_id
                init_params: some_params

                admin_interfaces:
                - driver:
                    type: websocket
                    port: 1234

                network:
                bootstrap_service: https://bootstrap-staging.holo.host
                transport_pool:
                    - type: webrtc
                    signal_url: wss://signal.holotest.net
                tuning_params:
                    gossip_loop_iteration_delay_ms: 42
                    default_rpc_single_timeout_ms: 42
                    default_rpc_multi_remote_agent_count: 42
                    default_rpc_multi_remote_request_grace_ms: 42
                    agent_info_expires_after_ms: 42
                    tls_in_mem_session_storage: 42
                    proxy_keepalive_ms: 42
                    proxy_to_expire_ms: 42
                network_type: quic_bootstrap

                db_sync_strategy: Fast
                ENDOFCFG
            ]
        }
    }
}
