{
  description = "hantverk: a deterministic Fabric modpack managed with packwiz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-minecraft,
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);

      # pack.toml is the single source of truth for game and loader versions.
      pack = builtins.fromTOML (builtins.readFile ./pack.toml);
      mcVersion = pack.versions.minecraft;
      fabricVersion = pack.versions.fabric;
    in
    {
      devShells = forAllSystems (
        pkgs: _: {
          default = pkgs.mkShell {
            packages = [
              pkgs.packwiz
              pkgs.git
            ];
          };
        }
      );

      packages = forAllSystems (
        pkgs: system:
        let
          mc = nix-minecraft.legacyPackages.${system};
          # Minecraft 26.x needs Java 25; nix-minecraft's Fabric wrapper defaults to 21.
          jre = pkgs.jdk25_headless;
          fabricServer =
            mc.fabricServers."fabric-${builtins.replaceStrings [ "." ] [ "_" ] mcVersion}".override
              {
                loaderVersion = fabricVersion;
                jre_headless = jre;
              };

          packwizInstaller = pkgs.fetchurl {
            url = "https://github.com/packwiz/packwiz-installer/releases/download/v0.5.8/packwiz-installer.jar";
            hash = "sha256-+sFi4ODZoMQGsZ8xOGZRir3a0oQWXjmRTGlzcXO/gPc=";
          };
          packwizBootstrap = pkgs.fetchurl {
            url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar";
            hash = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
          };
        in
        {
          # Local test server: syncs the working-tree pack into ./server-data and starts Fabric.
          # Usage: nix run .#server [-- <java args>]   (default: -Xms4G -Xmx4G)
          server = pkgs.writeShellApplication {
            name = "hantverk-server";
            runtimeInputs = [ jre ];
            text = ''
              root="$PWD"
              if [ ! -f "$root/pack.toml" ]; then
                echo "Run this from the hantverk repo root (no pack.toml in $root)" >&2
                exit 1
              fi
              data="''${HANTVERK_SERVER_DIR:-$root/server-data}"
              mkdir -p "$data"
              cd "$data"

              echo "eula=true" > eula.txt

              java -jar ${packwizBootstrap} \
                --bootstrap-main-jar ${packwizInstaller} \
                --bootstrap-no-update --no-gui --side server \
                "file://$root/pack.toml"

              # Server-only files tracked in the repo (whitelist, ops, ...) override what's in server-data.
              if [ -d "$root/server" ]; then
                cp -R "$root/server/." "$data/"
              fi

              if [ "$#" -eq 0 ]; then set -- -Xms4G -Xmx4G; fi
              exec ${pkgs.lib.getExe fabricServer} "$@"
            '';
          };
        }
      );

      apps = forAllSystems (
        _: system: {
          server = {
            type = "app";
            program = nixpkgs.lib.getExe self.packages.${system}.server;
          };
        }
      );

      formatter = forAllSystems (pkgs: _: pkgs.nixfmt);
    };
}
