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
            # Given a flake output key, how to get the buildable derivation for
            # any of its attr values?
            flakeSchema = {
              perSystem = {
                lookupFlake = k: lib.attrByPath [ k system ] { };
                getDrv = {
                  packages = _: x: [ x ];
                  checks = _: x: [ x ];
                  devShells = _: x: [ x ];
                  apps = _: app: [ app.program ];
                  legacyPackages = k: v:
                    if k == "homeConfigurations"
                    then
                      lib.mapAttrsToList (_: cfg: cfg.activationPackage) v
                    else [ ];
                };
              };
              flake = {
                lookupFlake = k: lib.attrByPath [ k ] { };
                getDrv = {
                  nixosConfigurations = _: cfg: [ cfg.config.system.build.toplevel ];
                  darwinConfigurations = _: cfg: [ cfg.config.system.build.toplevel ];
                };
              };
            };
            paths =
              lib.flip lib.mapAttrsToList flakeSchema (lvl: lvlSchema:
                lib.flip lib.mapAttrsToList lvlSchema.getDrv (kind: getDrv:
                  lib.mapAttrsToList
                    getDrv
                    (lvlSchema.lookupFlake kind inputs.flake))
              );
          in
          pkgs.runCommand "devour-output" { inherit paths; } ''
            echo -n $paths > $out
          '';
      };
    };
}
