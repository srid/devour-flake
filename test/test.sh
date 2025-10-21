set -euxo pipefail

cd "$(dirname "$0")"
rm -f result

nix build .. --override-input flake github:srid/haskell-multi-nix/c85563721c388629fa9e538a1d97274861bc8321 -L --no-link --print-out-paths | xargs cat > result

diff expected result

rm -f result