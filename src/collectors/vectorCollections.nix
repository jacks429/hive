{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "vectorCollections";
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        
        # Vector store reference
        store = config.store or ""; # Reference to a vectorStore
        
        # Collection schema
        schema = {
          dimensions = config.schema.dimensions or 768;
          metric = config.schema.metric or "cosine";
          
          # Vector fields
          vectorFields = config.schema.vectorFields or [{
            name = "embedding";
            dimensions = config.schema.dimensions or 768;
          }];
          
          # Payload/metadata fields
          payloadFields = config.schema.payloadFields or [];
          
          # Indexing configuration
          indexing = config.schema.indexing or {
            type = "hnsw";
            parameters = {
              m = 16;
              efConstruction = 100;
            };
          };
        };
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk