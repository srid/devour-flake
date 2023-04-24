{ pkgs, devour-flake, ... }:

# A convenient invoker for https://github.com/srid/devour-flake that then
# outputs the built derivations to stdout.
pkgs.writeShellApplication {
  name = "devour-flake-cat";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    nix build ${devour-flake}#default \
      -L --no-link --print-out-paths \
      --override-input flake "$1" \
      | xargs cat 
  '';
}
