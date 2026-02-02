{
  outputs = { self }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (name: { inherit name; value = f name; }) systems);
    in
    {
      packages = forAllSystems (system: {
        impure = derivation {
          name = "impure";
          inherit system;
          builder = "/bin/sh";
          args = ["-c" "echo impure > $out"];
          __impure = true;
        };
      });
    };
}