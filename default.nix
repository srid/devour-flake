{ pkgs, devour-flake, ... }:

# A convenient invoker for https://github.com/srid/devour-flake that then
# outputs the built derivations to stdout.
pkgs.writeShellApplication {
  name = "devour-flake";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    FLAKE="$1"
    shift 1 || true

    nix "$@" build ${devour-flake}#default \
      -L --no-link --print-out-paths \
      --override-input flake "$FLAKE" \
      | xargs cat 
  '';
}
