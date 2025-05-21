{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "vectorQueries";
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
        
        # Query configuration
        query = {
          type = config.query.type or "similarity"; # similarity, hybrid, filter
          topK = config.query.topK or 10;
          threshold = config.query.threshold or 0.7;
          
          # For hybrid search
          textWeight = config.query.textWeight or 0.5;
          vectorWeight = config.query.vectorWeight or 0.5;
          
          # For filtered search
          filter = config.query.filter or {};
        };
        
        # Embedding configuration for query text
        embedding = {
          model = config.embedding.model or "openai"; # openai, huggingface, custom
          dimensions = config.embedding.dimensions or 768;
          apiKey = config.embedding.apiKey or "";
          endpoint = config.embedding.endpoint or "";
        };
        
        # Output configuration
        output = {
          format = config.output.format or "json"; # json, csv, text
          includeMetadata = config.output.includeMetadata or true;
          includeVectors = config.output.includeVectors or false;
        };
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk