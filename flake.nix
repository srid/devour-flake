{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake.url = "github:srid/empty-flake"; # TODO: Change this to bottom-flake (error's out when building)
  };
  outputs = inputs@{ flake-parts, systems, flake, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem = { pkgs, lib, system, ... }: {
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
      };
    };
}
