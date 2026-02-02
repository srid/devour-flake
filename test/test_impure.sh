#!/usr/bin/env bash
set -euxo pipefail

# Navigate to test directory
cd "$(dirname "$0")"

echo "Running impure flake test..."

nix build .. --override-input flake path:./impure_flake

impure=$(nix eval ..#default.__impure --override-input flake path:./impure_flake)

if [[ $impure == true ]]; then
    echo "PASS: Derivation has __impure set to true."
else
    echo "FAIL: Derivation does NOT have __impure set to true."
    exit 1
fi

echo "Impure flake test passed!"
