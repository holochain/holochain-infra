# CI Infrastructure for Holochain

This is the declarative deployment of the holochain CI infrastructure.
All hosts are running either Linux or MacOS.

The linux hosts are managed via [NixOS](https://nixos.org/) and the MacOS hosts are managed via [nix-darwin](https://github.com/LnL7/nix-darwin).

For making changes to the nixos configuration files, please refer to the [nixos manual](https://nixos.org/manual/nixos/stable/index.html#ch-configuration).

For making changes to the macos configuration files, please refer to the [nix-darwin manual](https://daiderd.com/nix-darwin/manual/index.html).

## Development on this repo

This repository uses nix flakes. To interact with it, add the experimental features `flakes` and `nix-command` to your `~/.config/nix/nix.conf`:

```
experimental-features = flakes nix-command
```

Flakes have a standardized output schema, for which a good overview exists in the [nixos wiki](https://nixos.wiki/wiki/Flakes#Output_schema).

Before getting started, it is always a good idea to inspect the outputs of the current project:

```
nix flake show
```

Notice the field `nixosConfigurations` which lists all hosts managed by this repo.

## Repo structure

To change the definition of some attribute seen in `nix flake show`, adapt the files under `./modules/flake-parts`. The file and directory names seen in the `flake-parts` directory are similar to the flake output names.

Example: The definition for `nixosConfigurations.linux-builder-01` is located at `./modules/flake-parts/nixosConfigurations.linux-builder-01`.

Code shared between hosts should be factored out into one or more nixos modules located under `./modules/nixos/`.

## Module types & File structure

This project splits up its nix code into modules in order to improve maintainability and portability of the code.

There are two kinds of modules:

There are two kinds of modules:
 - **nixos modules**: located under `./modules/nixos`
	 - contain configuration for linux or macos hosts.
 - **flake-parts modules**: located under `./modules/flake-parts`
	 - export entities like packages, apps, or machine configurations via the flake outputs, the projects `public API` so to speak.
	 - are responsible for everything seen in the output of `nix flake show`.

A new flake module can be added by creating a new file under `./modules/flake-parts`. (Or a new directory containing a `default.nix` file)

A template for initializing new modules is located under `./modules/flake-parts/_template.nix`.

For more information on how to write flake modules, visit [flake.parts](https://flake.parts/).

## Deploying changes

After making changes to the configuration files of a host, a flake app must be executed in order to apply the changes to that host.

### Show available apps

```command
nix flake show
```

notice apps prefixed with `deploy-`

### Deploy changes to host

```command
nix run .#deploy-{hostname}
```

### Update dependencies (nixpkgs version)

```
nix flake update
```
