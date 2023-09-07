{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-schemas.url = "github:srid/flake-schemas";
    flake = { };
  };
  outputs = inputs@{ flake-parts, systems, ... }:
    let
      schema = import ./schema.nix;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      flake.contents = (schema.getFlakeOutputs "aarch64-darwin" inputs.flake).contents.inventory;
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
                  nixosConfigurations = _: cfg:
                    lib.optional pkgs.stdenv.isLinux cfg.config.system.build.toplevel;
                  darwinConfigurations = _: cfg:
                    lib.optional pkgs.stdenv.isDarwin cfg.config.system.build.toplevel;
                };
              };
            };
            contents = (schema.getFlakeOutputs system inputs.flake).contents;
            getOutputDrvsForLeaf = x:
              if lib.hasAttr "derivation" x then [ x.derivation ] else [ ];
            getOutputDrvs = xs:
              if lib.hasAttr "children" xs
              then lib.concatMap getOutputDrvs (lib.attrValues xs.children)
              else getOutputDrvsForLeaf xs;
            paths = lib.unique (lib.concatMap getOutputDrvs (lib.attrValues contents.inventory));
            pathsOld =
              lib.flip lib.mapAttrsToList flakeSchema (lvl: lvlSchema:
                lib.flip lib.mapAttrsToList lvlSchema.getDrv (kind: getDrv:
                  lib.mapAttrsToList
                    getDrv
                    (lvlSchema.lookupFlake kind inputs.flake))
              );
          in
          pkgs.writeText "devour-output" (lib.strings.concatLines (lib.lists.flatten paths));
      };
    };
}
