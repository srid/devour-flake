{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake = { };
  };
  outputs = inputs@{ self, flake-parts, systems, flake, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem = { self', pkgs, lib, system, ... }: {
        packages.default =
          let
            lookupFlake = k:
              lib.attrByPath [ k system ] { };
            paths = lib.concatMap lib.attrValues [
              (lookupFlake "packages" flake)
              (lookupFlake "checks" flake)
              (lookupFlake "devShells" flake)
              (lib.mapAttrs (_: app: app.program)
                (lookupFlake "apps" flake))
            ];
          in
          pkgs.runCommand "devour-output" { inherit paths; } ''
            echo -n $paths > $out
          '';

        apps.default.program = pkgs.writeShellApplication {
          name = "devour-flake";
          runtimeInputs = [ pkgs.nix ];
          text = ''
            nix build -L --no-link --print-out-paths ${self}#default --override-input flake "$1" \
              | xargs cat
          '';
        };
      };
    };
}
