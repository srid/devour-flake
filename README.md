# devour-flake

Devour all outputs in a flake.

## Why?

Running `nix build .#a .#b ... .#z` on a flake with that many outputs can be rather slow if the evaluation of those packages are non-trivial. Nix evaluates separately for *each* of the argument (as if not using the [eval cache](https://www.tweag.io/blog/2020-06-25-eval-cache/)).

To workaround this, we create a "consumer" flake that will depend on all outputs in the given input flake, and then run `nix build` *on the* consumer flake, which will then evaluate the input flake's packages only once.


## Usage

To build all of the [nammayatri](https://github.com/nammayatri/nammayatri) flake outputs for example:

```bash
nix build github:srid/devour-flake \
  -L --no-link --print-out-paths \
  --override-input flake github:nammayatri/nammayatri
```

Pipe this to `| xargs cat | cachix push <name>` to [push all flake outputs to cachix](https://github.com/juspay/jenkins-nix-ci/commit/71003fbaaba8a17e02bc74c70504ebacc6a5818c)!

<details>
<summary>WIP</summary>
Alternatively, you can also `nix run` this program directly:

```bash
nix run github:srid/devour-flake github:nammayatri/nammayatri \
  | cachix push <name>
``` 
</details>