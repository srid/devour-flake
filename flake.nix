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
            drvs = lib.concatMap builtins.attrValues [
              flake.packages.${system}
              flake.checks.${system}
              flake.devShells.${system}
            ];
            paths = map (app: app.program) (lib.attrValues
              flake.apps.${system});
          in
          pkgs.runCommand "devour-output" { inherit drvs paths; } ''
            touch $out
            echo $drvs | tee -a $out
            echo $paths | tee -a $out
          '';
      };
    };
}
