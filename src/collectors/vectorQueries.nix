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
      (l.mapAttrs (target: config: {
        # Extract query definition
        name = config.name or target;
        description = config.description or "";
        
        # Collection to query
        collection = config.collection or "default";
        
        # Query parameters
        topK = config.topK or 10;
        
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
