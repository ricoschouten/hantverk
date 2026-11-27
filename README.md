# hantverk

A Fabric modpack for Minecraft 26.3, managed with [packwiz](https://github.com/packwiz/packwiz).
Every mod is pinned by URL and hash, so a given commit always produces the same pack.

## Setup

Tools come from the Nix flake, with versions pinned in `flake.lock`:

```sh
nix develop           # shell with packwiz on PATH
nix flake update      # deliberately bump the toolchain
```

## Common tasks

```sh
packwiz modrinth add <slug>     # add a mod from Modrinth
packwiz curseforge add <slug>   # add a mod from CurseForge
packwiz remove <name>
packwiz update --all            # upgrade mods (review the diff before committing)
packwiz refresh                 # rebuild index.toml after editing files in config/
packwiz modrinth export         # build a .mrpack for Prism Launcher / Modrinth App
```

Mod configs go in `config/`. Run `packwiz refresh` afterwards so they get indexed.

## Testing

Client: export the pack and import the `.mrpack` into Prism Launcher.

```sh
nix develop -c packwiz modrinth export
```

Server: run a local Fabric server built with [nix-minecraft](https://github.com/Infinidoge/nix-minecraft):

```sh
nix run .#server                    # defaults to -Xms4G -Xmx4G
nix run .#server -- -Xmx8G          # custom JVM args
```

It reads the Minecraft and Fabric versions from `pack.toml` and syncs the working-tree pack into
`server-data/` with packwiz-installer (server-side mods only). Then it starts the server on port 25565.
Running it accepts the Minecraft EULA (https://aka.ms/MinecraftEULA) by writing `eula.txt`.
Set `HANTVERK_SERVER_DIR` to use a different data directory.

## Releases

Push a tag like `v0.1.0`. CI checks the index, builds the `.mrpack` and attaches it to a GitHub release.
Bump `version` in `pack.toml` first.

## Installing from the hosted pack

Players and servers can stay in sync using [packwiz-installer](https://packwiz.infra.link/tutorials/installing/packwiz-installer/) pointed at:

```
https://raw.githubusercontent.com/ricoschouten/hantverk/main/pack.toml
```
