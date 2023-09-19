* introduction tutorial: https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls

* creating a new server key with an additional (WAN-facing) IP address
    ```
    nomad tls cert create -server -ca secrets/nomad/admin/nomad-agent-ca.pem -key <(sops -d secrets/nomad/admin/keys.yaml | yq '.nomad-agent-ca-key') -additional-ipaddress 5.78.43.185
    ```
