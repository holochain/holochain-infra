# Nix Cache VM

## Server set up

### Starting the VM

```
nix run .#nixosConfigurations.vm-nixcache.config.microvm.declaredRunner
```

This will yield a root shell inside the VM.

### Connect via SSH

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o CheckHostIP=no root@localhost -p 2222
```

Watch cache population progress

```
journalctl -f -b0 -n100 --unit populate-cache
```

## Client set up

TODO