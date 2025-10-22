{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
          pkgs = import inputs.nixpkgs { inherit system; };
          lib = pkgs.lib;
          build-systems =
            let systems = import inputs.systems;
            in if systems == [ ] then [ system ] else systems;
          getSystem = cfg: cfg.pkgs.stdenv.hostPlatform.system;
          nameForStorePath = path:
            if builtins.typeOf path == "set"
            then path.pname or path.name or null
            else null;

          # Collect paths for a specific system
          collectPathsForSystem = sys:
            let
              # Helper to extract derivations from attrs
              getDrvs = kind: attrs:
                if kind == "packages" || kind == "checks" || kind == "devShells" then
                  lib.attrValues attrs
                else if kind == "apps" then
                  map (app: app.program) (lib.attrValues attrs)
                else if kind == "legacyPackages" then
                  lib.optionals (attrs ? homeConfigurations)
                    (lib.mapAttrsToList (_: cfg: cfg.activationPackage) attrs.homeConfigurations)
                else [ ];

              # Per-system outputs
              perSystemPaths = lib.concatMap (kind:
                getDrvs kind (lib.attrByPath [ kind sys ] { } inputs.flake)
              ) [ "packages" "checks" "devShells" "apps" "legacyPackages" ];

              # Flake-level outputs (nixosConfigurations, darwinConfigurations)
              flakePaths = lib.concatMap (kind:
                let
                  configs = lib.attrByPath [ kind ] { } inputs.flake;
                  configsForSys = lib.filterAttrs (_: cfg:
                    getSystem cfg == sys
                  ) configs;
                in
                  map (cfg: cfg.config.system.build.toplevel) (lib.attrValues configsForSys)
              ) [ "nixosConfigurations" "darwinConfigurations" ];
            in
              perSystemPaths ++ flakePaths;

          # Build result organized by system
          result = builtins.listToAttrs (map (sys:
            let
              allPaths = collectPathsForSystem sys;
              uniquePaths = lib.unique allPaths;
              outPaths = lib.sort (a: b: "${a}" < "${b}") uniquePaths;
              byName = lib.foldl' (acc: path:
                let name = nameForStorePath path;
                in if name == null then acc else acc // { "${name}" = path; }
              ) { } outPaths;
            in
              { name = sys; value = { inherit outPaths byName; }; }
          ) build-systems);
        in
        {
          default = pkgs.writeText "devour-output.json" (builtins.toJSON result);
        }
      );
    };
}
