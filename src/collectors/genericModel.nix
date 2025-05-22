{ inputs, cell, modelType ? "generic", cliPrefix ? "run" }:
let
  inherit (inputs) nixpkgs;
  l = nixpkgs.lib // builtins;
  
  # Ensure modelType is defined - use a default if null
  actualModelType = if modelType != null then modelType else "generic";
  
  # Load all model configurations for this modelType
  configs = if cell != null && builtins.hasAttr actualModelType cell
            then cell.${actualModelType} 
            else {};
  
  # Create registry entries for each model
  registry = l.mapAttrs (name: config: {
    modelUri = config.modelUri or "";
    framework = config.framework or "generic";
    params = config.params or {};
    meta = {
      name = config.name or name;
      description = config.description or "";
      modelType = actualModelType;
      tags = config.tags or [];
      license = config.license or "unknown";
      metrics = config.metrics or {};
    } // (config.meta or {});
    service = config.service or {
      enable = false;
      host = "0.0.0.0";
      port = 8000;
    };
    system = config.system or "x86_64-linux";
  }) configs;
  
  # Create the result with a fixed attribute name
  result = {
    registry = registry;
  };
in
  result // { "${actualModelType}Registry" = registry; } 
