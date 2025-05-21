{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract model definition
  model = {
    inherit (config) name type description framework modelUri version params system;
    inherit (config) loadExpr processExpr service;
  };
  
  # Import shared utilities
  nlpModelWrapper = import ../utils/nlpModelWrapper.nix {
    inherit nixpkgs root inputs;
  };
  
  nlpServiceWrapper = import ../utils/nlpServiceWrapper.nix {
    inherit nixpkgs root inputs;
  };
  
  # Create model wrapper
  modelWrapper = nlpModelWrapper model;
  
  # Create service wrapper if enabled
  serviceWrapper = if model.service.enable or false
                   then nlpServiceWrapper model
                   else null;
  
  # Generate documentation
  modelDocs = ''
    # ${model.type}: ${model.name} (version ${model.version})
    
    ${model.description}
    
    ## Overview
    
    - **Framework:** ${model.framework}
    - **Model URI:** ${model.modelUri}
    
    ## Parameters
    
    ${l.concatMapStrings (key: "- **${key}:** ${l.toJSON model.params.${key}}\n") 
      (l.attrNames (model.params or {}))}
    
    ## Usage
    
    ```bash
    # Process text from stdin
    echo "Text to summarize" | nix run .#run-${model.type}-${model.name}
    
    # Process text from file
    nix run .#run-${model.type}-${model.name} -- input.txt
    
    ${if model.service.enable or false then ''
    # Start as a service
    nix run .#serve-${model.type}-${model.name}
    
    # Then use the API
    curl -X POST http://${model.service.host or "0.0.0.0"}:${toString (model.service.port or 8000)}/process \
      -H "Content-Type: application/json" \
      -d '{"text": "Text to summarize"}'
    '' else ""}
    ```
  '';
  
  # Create documentation derivation
  modelDocsDrv = pkgs.writeTextFile {
    name = "${model.name}-${model.type}.md";
    text = modelDocs;
  };
  
in {
  # Original model data
  inherit (model) name type framework;
  inherit (model) modelUri params version description;
  
  # Enhanced outputs
  runScript = modelWrapper;
  serviceScript = serviceWrapper;
  documentation = modelDocsDrv;
  
  # Add metadata
  metadata = model.metadata or {};
}