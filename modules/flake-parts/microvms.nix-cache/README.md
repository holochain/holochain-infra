# Nix Cache MicroVM

This machine can be used to set up a holochain nix cache for local networks.
Once booted the cache will be continously updated.

The current plan is to use one signing key per event.
In this document all examples are given for the _hackathons_ event (Amsterdam September 2023 Hackathon).

## Requirements

### Signing Keys

We rely on signing the binary packages for security. The existing signing keys are amanaged via the [.sops.yaml](../../.sops.yaml).
Check in with an admin to get your key added.


#### Generating a new signing key

```
nix key generate-secret --key-name hackathons.events.infra.holochain.org-1 > secrets/events-nix-cache/hackathons.secret
nix key convert-secret-to-public < secrets/events-nix-cache/harmonia.secret > secrets/events-nix-cache/hackathons.pub
```

TODO: document how to add the key to SOPS

### DNS
We rely on a public DNS server to point to local IP addresses which needs to be configured once the IP of the machine running the VM is known.
For this purpose we have a DNS that we can add subdomains to. It's configured via the [../nixosConfigurations.dweb-reverse-tls-proxy/configuration.nix](../nixosConfigurations.dweb-reverse-tls-proxy/configuration.nix)

Example:

```zone
      hackathons.events.${fqdn2domain}.     A 192.168.15.11
```

Once the entry is made re-deploy the server:

```
nix run .#deploy-dweb-reverse-tls-proxy

# TODO: understand why this doesn't happen automatically
# reload the bind service
nix run .#ssh-dweb-reverse-tls-proxy "systemctl restart bind"
```

### Ensure your SSH key is configured

Either in the `flake.nix` as an input like

```nix
    keys_steveej = {
      url = "https://github.com/steveej.keys";
      flake = false;
    };
```

or via the [machine's config file](./configuration.nix_) to the list at `users.extraUsers.root.openssh.authorizedKeys.keys`.


## Server setup on a developer machine

The machine will allocate 100GB disk space on first start.
It's currently required to manually put in the signing key.


### Starting the VM

```
mkdir .storage
nix run .#nixosConfigurations.vm-nixcache.config.microvm.declaredRunner
```

This will yield a root shell inside the VM. This shell will remain available for the remainder of the VMs runtime.
Currently there is no designated way to run the VM in the background.

### Copy the signing key via SSH

The VM doesn't have a predictable SSH host key. The following command ignores any host key mismatches while connecting.

```
nix develop --command bash -c "sops -d secrets/events-nix-cache.yml | yq '.hackathons_secret'" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o CheckHostIP=no root@hackathons.events.infra.holochain.org -p 2222 "cat > /nix/.rw-store/harmonia.secret; systemctl restart harmonia"
```

### Watch cache population progress

This command works best via SSH because of the limitation of the VMs terminal. See the previous section for the SSH connection command.

```
journalctl -f -b0 -n100 --unit populate-cache
```

### Running the reverse-proxy on port 80

We delegate the opening of port 80 to a distinct reverse-proxy that is run with `sudo`. Otherwise we could need `sudo` for the VM command would be unnecessary.

```
nix run .#reverse-proxy-nix-cache
```

### Testing the setup

```
nix build --refresh -vL -j0 \
  --extra-trusted-public-keys $(cat ./secrets/events-nix-cache/hackathons.pub) \
  --substituters "http://127.0.0.1:5000" \
  --override-input versions 'github:holochain/holochain?dir=versions/0_1' \
  github:holochain/holochain#devShells.x86_64-linux.holonix
```

## Client setup

This is [documented under holochain.org](https://developer.holochain.org/get-building/at-an-event).
