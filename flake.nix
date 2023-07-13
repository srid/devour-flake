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
            # Given a flake output key, how to get the buildable derivation for
            # any of its attr values?
            drvFor = {
              packages = x: x;
              checks = x: x;
              devShells = x: x;
              apps = app: app.program;
            };
            paths =
              lib.flip lib.mapAttrsToList drvFor (kind: getDrv:
                builtins.map
                  getDrv
                  (lib.attrValues (lookupFlake kind inputs.flake)));
          in
          pkgs.runCommand "devour-output" { inherit paths; } ''
            echo -n $paths > $out
          '';
      };
    };
}
