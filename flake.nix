{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    allowed-systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # The systems to build for. If empty, build for current system.
    systems.url = "github:srid/empty";
    flake = { };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.allowed-systems;
      perSystem = { self', pkgs, lib, system, ... }: {
        packages.default =
          let
            build-systems =
              let systems = import inputs.systems;
              in if systems == [ ] then [ system ] else systems;
            shouldBuildOn = s: lib.elem s build-systems;
            getSystem = cfg:
              cfg.pkgs.stdenv.hostPlatform.system;
            configForCurrentSystem = cfg:
              shouldBuildOn (getSystem cfg);
            # Given a flake output key, how to get the buildable derivation for
            # any of its attr values?
            flakeSchema = {
              perSystem = {
                # -> [ path ]
                lookupFlake = k: flake:
                  lib.flip builtins.map build-systems (sys:
                    lib.attrByPath [ k sys ] { } flake
                  );
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
                lookupFlake = k: flake: [ (lib.attrByPath [ k ] { } flake) ];
                getDrv = {
                  nixosConfigurations = _: cfg:
                    lib.optional (configForCurrentSystem cfg) cfg.config.system.build.toplevel;
                  darwinConfigurations = _: cfg:
                    lib.optional (configForCurrentSystem cfg) cfg.config.system.build.toplevel;
                };
              };
            };
            paths =
              lib.flip lib.mapAttrsToList flakeSchema (_: lvlSchema:
                lib.flip lib.mapAttrsToList lvlSchema.getDrv (kind: getDrv:
                  builtins.concatMap
                    (attr: lib.mapAttrsToList getDrv attr)
                    (lvlSchema.lookupFlake kind inputs.flake)
                )
              );
          in
          pkgs.writeText "devour-output" (lib.strings.concatLines (lib.lists.flatten paths));
      };
    };
}
