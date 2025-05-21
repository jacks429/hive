{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "schemaEvolution";
  type = "schemaEvolution";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    schema = inputs.${fragment}.${target};
    
    # Create migration scripts
    migrateUp = pkgs.writeShellScriptBin "migrate-${target}-up" ''
      echo "Running migration UP for ${schema.target} to version ${schema.version}"
      ${schema.upScript}
    '';
    
    migrateDown = pkgs.writeShellScriptBin "migrate-${target}-down" ''
      echo "Running migration DOWN for ${schema.target} from version ${schema.version}"
      ${schema.downScript}
    '';
    
  in [
    (mkCommand currentSystem {
      name = "migrate-${target}-up";
      description = "Migrate ${schema.target} UP to version ${schema.version}";
      package = migrateUp;
    })
    (mkCommand currentSystem {
      name = "migrate-${target}-down";
      description = "Migrate ${schema.target} DOWN from version ${schema.version}";
      package = migrateDown;
    })
  ];
}