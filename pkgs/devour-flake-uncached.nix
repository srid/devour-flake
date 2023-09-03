{ coreutils-full
, findutils
, jq
, nix
, nix-build-uncached
, writeShellApplication
}:

writeShellApplication {
  name = "devour-flake-uncached";
  runtimeInputs = [
    coreutils-full
    findutils
    jq
    nix
    nix-build-uncached
  ];
  text = ''
    set -euo pipefail

    FLAKE="$1"
    shift 1 || true

    outDir=$(mktemp -d devour-flake-uncached.XXXX)
    cleanup() {
      rm -rf "$outDir"
    }
    trap cleanup EXIT

    nix derivation show \
      ${../devour}#default \
      "$@" \
      -L \
      --reference-lock-file ${../flake.lock} \
      --override-input flake "$FLAKE" \
      | jq -r 'to_entries[].value.inputDrvs | to_entries[].key' \
      | (
        cd "$outDir"
        1>&2 xargs nix-build-uncached
        readlink ./*
      )
  '';
}
