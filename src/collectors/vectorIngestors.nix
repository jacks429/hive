{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "vectorIngestors";
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
        
        # Target collection
        collection = config.collection or ""; # Reference to a vectorCollection
        
        # Source data configuration
        source = {
          type = config.source.type or "file"; # file, directory, database, api
          format = config.source.format or "json"; # json, csv, text, etc.
          path = config.source.path or "";
          query = config.source.query or "";
          filter = config.source.filter or "";
        };
        
        # Embedding configuration
        embedding = {
          model = config.embedding.model or "openai"; # openai, huggingface, custom
          dimensions = config.embedding.dimensions or 768;
          batchSize = config.embedding.batchSize or 100;
          apiKey = config.embedding.apiKey or "";
          endpoint = config.embedding.endpoint or "";
        };
        
        # Processing steps
        steps = config.steps or [];
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk