{
  # (getFlakeOutputs "aarch64-darwin" inputs.flake).contents;
  getFlakeOutputs = currentSystem: flake:
    let
      # Helper functions.
      mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (builtins.attrNames attrs);
      mkChildren = children: { inherit children; };

    in
    rec {

      allSchemas = flake.outputs.schemas or defaultSchemas;

      # FIXME: make this configurable
      # defaultSchemas = (builtins.getFlake "https://api.flakehub.com/f/pinned/DeterminateSystems/flake-schemas/0.1.0/018a4772-ff17-7bdd-b647-135e49b02555/source.tar.gz?narHash=sha256-n6IV%2BNg1UusvBQSWwztOgwifcGzvsUQyJG14vwAoJn4%3D").schemas;
      defaultSchemas = (builtins.getFlake "https://github.com/srid/flake-schemas/archive/refs/heads/patch-2.tar.gz?narHash=sha256-Fs6At5XxxyAi1Rg%2FYoYOs5uQME8b79zDX8WwM99VPQ8%3D").schemas;
      # defaultSchemas = inputs.flake-schemas;

      schemas =
        builtins.listToAttrs (builtins.concatLists (mapAttrsToList
          (outputName: output:
            if allSchemas ? ${outputName} then
              [{ name = outputName; value = allSchemas.${outputName}; }]
            else
              [ ])
          flake.outputs));

      docs =
        builtins.mapAttrs (outputName: schema: schema.doc or "<no docs>") schemas;

      uncheckedOutputs =
        builtins.filter (outputName: ! schemas ? ${outputName}) (builtins.attrNames flake.outputs);

      inventoryFor = filterFun:
        builtins.mapAttrs
          (outputName: schema:
            let
              doFilter = attrs:
                if filterFun attrs
                then
                  if attrs ? children
                  then
                    mkChildren (builtins.mapAttrs (childName: child: doFilter child) attrs.children)
                  else
                    attrs
                else
                  { };
            in
            doFilter ((schema.inventory or (output: { })) flake.outputs.${outputName})
          )
          schemas;

      inventoryForSystem = system: inventoryFor (itemSet:
        !itemSet ? forSystems
        || builtins.any (x: x == system) itemSet.forSystems);

      inventory = inventoryForSystem currentSystem;

      contents = {
        version = 1;
        inherit docs;
        inherit inventory;
      };
    };
}
