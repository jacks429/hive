{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "summarizers";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        # Extract model definition
        name = config.name or target;
        type = "summarizer";
        description = config.description or "";
        
        # Model information
        framework = config.framework or "huggingface";
        modelUri = config.modelUri or "";
        version = config.version or "1.0.0";
        
        # Model parameters
        params = config.params or {};
        
        # Custom expressions
        loadExpr = config.loadExpr or null;
        processExpr = config.processExpr or null;
        
        # Service configuration (optional)
        service = config.service or {
          enable = false;
          host = "0.0.0.0";
          port = 8000;
        };
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk
