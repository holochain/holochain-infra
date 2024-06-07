# Pulumi Deployments

This is under active developments.

Please see the list of [all Pulumi related issues](https://github.com/holochain/holochain-infra/issues?q=is%3Aissue+is%3Aopen+pulumi).

## Example Usage

This example requires `mycelium` running on the executing system.

Bring up the stack

```
pulum up
```

Check whether the machine is up

```
ssh root@$(pulumi stack -s dev output mycelium_ip)
```


Deploy another NixOS config to the VM and reboot it:

```
scripts/deploy.sh
```

## Debugging

If the VM is not responding to SSH requests it's possible to connect to its terminal directly via the web console.

This requires NetworkManger installed on the executing system.

```
scripts/wireguard.sh
```

Display the console:

```
echo "http://$(pulumi stack -s dev output vm0 | jq --raw-output .console_url)"
```
