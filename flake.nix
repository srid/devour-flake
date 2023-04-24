{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake = { };
  };
  outputs = inputs@{ flake-parts, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem = { self', pkgs, lib, system, ... }: {
        packages.default =
          let
            lookupFlake = k:
              lib.attrByPath [ k system ] { };
            paths = lib.concatMap lib.attrValues [
              (lookupFlake "packages" inputs.flake)
              (lookupFlake "checks" inputs.flake)
              (lookupFlake "devShells" inputs.flake)
              (lib.mapAttrs (_: app: app.program)
                (lookupFlake "apps" inputs.flake))
            ];
          in
          pkgs.runCommand "devour-output" { inherit paths; } ''
            echo -n $paths > $out
          '';
      };
    };
}
