{ writeShellApplication, nix, ... }:

# A convenient invoker for https://github.com/srid/devour-flake that then
# outputs the built derivations to stdout.
writeShellApplication {
  name = "devour-flake";
  runtimeInputs = [ nix ];
  text = ''
    FLAKE="$1"
    shift 1 || true

    nix build ${./.}#default \
      "$@" \
      -L --no-link --print-out-paths \
      --override-input flake "$FLAKE" \
      | xargs -I{} sh -c 'echo -n "{} "; cat {}'
  '';
}
