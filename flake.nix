{
  inputs = {
    # The systems to build for. If empty, build for current system.
    systems.url = "github:srid/empty";
    flake = { };
  };
  outputs = inputs:
    let
      allSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (system: { name = system; value = f system; }) allSystems);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import inputs.flake.inputs.nixpkgs { inherit system; };
          lib = pkgs.lib;
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
          # Group paths by system
          pathsBySystem =
            lib.flip lib.mapAttrsToList flakeSchema (_: lvlSchema:
              lib.flip lib.mapAttrsToList lvlSchema.getDrv (kind: getDrv:
                # For perSystem outputs, return system-tagged paths
                if lvlSchema ? lookupFlake && kind != "nixosConfigurations" && kind != "darwinConfigurations"
                then
                  lib.flip builtins.map build-systems (sys:
                    let attr = lib.attrByPath [ kind sys ] { } inputs.flake;
                    in {
                      system = sys;
                      paths = lib.mapAttrsToList getDrv attr;
                    }
                  )
                else
                  # For flake-level outputs, assign based on target system
                  let attr = lib.attrByPath [ kind ] { } inputs.flake;
                  in lib.mapAttrsToList (_: cfg:
                    {
                      system = getSystem cfg;
                      paths = getDrv _ cfg;
                    }
                  ) attr
              )
            );
          nameForStorePath = path:
            if builtins.typeOf path == "set"
              then path.pname or path.name or null
              else null;

          # Build result for each system
          buildResultForSystem = sys:
            let
              systemPaths = lib.lists.flatten (
                lib.filter (x: x.system == sys)
                  (lib.lists.flatten (lib.lists.flatten pathsBySystem))
              );
              outPaths =
                let flattened = lib.lists.flatten (map (x: x.paths) systemPaths);
                in lib.sort (a: b: toString a < toString b) flattened;
            in rec {
              inherit outPaths;
              byName = lib.foldl' (acc: path:
                let name = nameForStorePath path;
                in if name == null then acc else
                  acc // { "${name}" = path; }
              ) { } outPaths;
            };

          result = lib.listToAttrs (
            map (sys: {
              name = sys;
              value = buildResultForSystem sys;
            }) build-systems
          );
        in
        rec {
          json = pkgs.writeText "devour-output.json" (builtins.toJSON result);
          default = pkgs.writeText "devour-output" (
            lib.strings.concatLines (
              lib.lists.flatten (
                lib.mapAttrsToList (_: v: v.outPaths) result
              )
            )
          );
        }
      );
    };
}
