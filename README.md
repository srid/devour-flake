# devour-flake

Devour all outputs in a flake.

<img src="./logo.webp" width=200 />

## Why?

Running `nix build .#a .#b ... .#z` on a flake with that many outputs can be rather slow if the evaluation of those packages are non-trivial, as is often the case when using [IFD](https://nixos.wiki/wiki/Import_From_Derivation). Nix evaluates separately for *each* of the argument (as if not using the [eval cache](https://www.tweag.io/blog/2020-06-25-eval-cache/)).

To workaround this, we create a "consumer" flake that will depend on all outputs in the given input flake, and then run `nix build` *on the* consumer flake, which will then evaluate the input flake's packages only once.

devour-flake currently detects the following flake outputs:

| Type | Output Key |
| -- | -- |
| Standard flake outputs | `packages`, `apps`, `checks`, `devShells` |
| NixOS | `nixosConfigurations.*` |
| nix-darwin | `darwinConfigurations.*` |
| home-manager | `legacyPackages.${system}.homeConfigurations.*` |


## Usage

To build all of the [nammayatri](https://github.com/nammayatri/nammayatri) flake outputs for example:

```bash
nix build github:srid/devour-flake \
  -L --no-link --print-out-paths \
  --override-input flake github:nammayatri/nammayatri
```

Pipe this to `| cachix push <name>` to [push all flake outputs to cachix](https://github.com/juspay/jenkins-nix-ci/commit/71003fbaaba8a17e02bc74c70504ebacc6a5818c)!

### Nix app


Add this repo as a non-flake input:

```nix
{
  inputs = {
    devour-flake.url = "github:srid/devour-flake";
    devour-flake.flake = false;
  };
}
```

Then, add an overlay entry to your nixpkgs:

```nix
{
  devour-flake = self.callPackage inputs.devour-flake { };
}
```

Use `pkgs.devour-flake` to get a convenient executable that will devour the given flake and spit out the out paths. You can then use this in CI to build all outputs of a flake.

#### `nix-build-all`

> **Note**
>
> **See also**: [nixci](https://github.com/srid/nixci), an improved version of `nix-build-all`.

For a CI-friendly command that builds all flake outputs, in addition to checking for `flake.lock` consistency, use:

```nix
{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "nix-build-all";
  runtimeInputs = [
    pkgs.nix
    pkgs.devour-flake
  ];
  text = ''
    # Make sure that flake.lock is sync
    nix flake lock --no-update-lock-file

    # Do a full nix build (all outputs)
    # This uses https://github.com/srid/devour-flake
    devour-flake . "$@"
  '';
}
```


## Who uses it

- [Omnix](https://omnix.page/om/ci.html) (formerly [nixci](https://github.com/srid/nixci)): One command to run full Nix builds in CI or locally
- [jenkins-nix-ci](https://github.com/juspay/jenkins-nix-ci): Build all flake outputs in Jenkins, and push them to cachix.
- Other projects:
  - [horizon-platform](https://gitlab.horizon-haskell.net/package-sets/horizon-platform/-/merge_requests/28/diffs)
