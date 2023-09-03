{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem = { self', pkgs, lib, system, ... }: {
        packages = rec {
          default = pkgs.symlinkJoin {
            name = "devour-flake";
            paths = [
              devour-flake
              devour-flake-uncached
            ];
          };

          # Build all derivations in a flake (or download them from the cache)
          devour-flake = pkgs.callPackage ./pkgs/devour-flake.nix { };
          # Only build all uncached derivations in flake
          devour-flake-uncached = pkgs.callPackage ./pkgs/devour-flake-uncached.nix { };
        };
      };
    };
}
