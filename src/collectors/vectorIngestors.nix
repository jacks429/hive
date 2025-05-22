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
        # Extract ingestor definition
        name = config.name or target;
        description = config.description or "";
        
        # Collection to store vectors
        collection = config.collection or "default";
        
        # Data sources
        sources = config.sources or [];
        
        # Processing steps
        processors = config.processors or [];
        
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
