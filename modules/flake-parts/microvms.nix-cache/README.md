# Nix Cache VM

## Execution

Run it with

```
nix run .#nixosConfigurations.vm-nixcache.config.microvm.declaredRunner
```

Connect to SSH

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o CheckHostIP=no root@localhost -p 2222
```

Watch cache population progress

```
journalctl -f -b0 -n100
```

## Client set up

TODO