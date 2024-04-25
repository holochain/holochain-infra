This example adds the machine configuration `turn-2`.

1. order a VPS on hetzner

2. add 2 additional floating IPv4 addresses to it

3. copy the flake-parts config and adjust the names
    ```
    cp -r modules/flake-parts/nixosConfigurations.turn-{1,2}
    git add modules/flake-parts/nixosConfigurations.turn-2
    sed -i 's/-1/-2/g' modules/flake-parts/nixosConfigurations.turn-2/*.nix
    ```

4. change the IP addresses in *modules/flake-parts/nixosConfigurations.turn-2/configuration.nix*.
    these are the main and floating IPs of the VPS:

    ```nix
    (...)

    }: let
    hostName = "turn-2";

    turnIpv4 = "65.109.140.0";
    turnFqdn = "${hostName}.infra.holochain.org";

    signalIpv4 = "95.217.25.40";
    signalFqdn = "signal-2.infra.holochain.org";

    bootstrapIpv4 = "95.216.176.124";
    bootstrapFqdn = "bootstrap-2.infra.holochain.org";
    in {

    (...)

5. add the DNS and reverse-proxy entries to *modules/flake-parts/nixosConfigurations.dweb-reverse-tls-proxy/configuration.nix*
    * add entries for `{turn,signal,bootstrap}-2` to the bind config:
        ```nix
        (...)

        environment.etc."bind/zones/${fqdn2domain}.zone" = {
            enable = true;
            user = "named";
            group = "named";
            mode = "0644";
            text = ''

            (...)

            turn-2.${fqdn2domain}.                     A       ${self.nixosConfigurations.turn-2.config.services.holochain-turn-server.address}
            signal-2.${fqdn2domain}.                   A       ${self.nixosConfigurations.turn-2.config.services.tx5-signal-server.address}
            bootstrap-2.${fqdn2domain}.                A       ${self.nixosConfigurations.turn-2.config.services.kitsune-bootstrap.address}
            '';
        };

        (...)
        ```

    * add a reverse proxy entry to the caddy config:
        ```nix
        (...)

        services.caddy.virtualHosts = {
            (...)


            "acme-turn-2.${fqdn2domain}:80" = {
            extraConfig = ''
                reverse_proxy http://turn-2.${fqdn2domain}:${builtins.toString self.nixosConfigurations.turn-2.config.services.holochain-turn-server.nginx-http-port}
            '';
            };
        };

        (...)
        ```

6. rebuild the DNS server and restart the bind service
    ```
    nix run .\#deploy-dweb-reverse-tls-proxy switch
    nix run .\#ssh-dweb-reverse-tls-proxy "systemctl restart bind"
    ```

7. verify the records
    ```
    nix run nixpkgs#dig +short {turn,signal,bootstrap}-2.infra.holochain.org @infra.holochain.org
    65.109.140.0
    95.217.25.40
    95.216.176.124
    ```
8. deploy nixos on the new VPS. replace $IP with the primary IP of the VPS:

    ```
    nix run .#nixos-anywhere -- --flake .\#turn-2 root@$IP

    (...)

    ### Waiting for the maching to become reachable again ###
    Warning: Permanently added '65.109.140.0' (ED25519) to the list of known hosts.
    ### Done! ###
    ```

    this should take about 2-3 minutes.

9. verify the functionality of the signal and turn stack.

    ```
    nix shell .#tx5 --command bash -c '
        set -e;
        turn-stress turn-2.infra.holochain.org 443 test test;
        turn_doctor wss://signal-2.infra.holochain.org;
        echo success
    '
    ```

10. commit the changes to git and get them to develop
