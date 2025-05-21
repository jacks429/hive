{ inputs, nixpkgs, root }:
config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create service script
  serviceScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting vector search service: ${config.name}"
    echo "Listening on ${config.service.host}:${toString config.service.port}"
    
    # Ensure vector directory exists
    VECTOR_DIR="${config.vectorDir}"
    if [ ! -d "$VECTOR_DIR" ]; then
      echo "Vector directory not found: $VECTOR_DIR"
      echo "Please run the vector ingestor first."
      exit 1
    fi
    
    # Run the vector search service
    ${pkgs.python3.withPackages (ps: with ps; [ 
      fastapi uvicorn numpy sentence-transformers
    ])}/bin/python ${root.utils.vectorSearch}/service.py \
      --vector-dir "$VECTOR_DIR" \
      --host "${config.service.host}" \
      --port "${toString config.service.port}" \
      --embedder-model "${config.embedder.model}"
  '';
  
  # Create documentation
  documentation = ''
    # Vector Search Service: ${config.name}
    
    ${config.description}
    
    ## Collection
    
    This service searches the **${config.collection}** vector collection.
    
    ## Vector Directory
    
    The service uses vectors stored in: ${config.vectorDir}
    
    ## Service Configuration
    
    - Host: ${config.service.host}
    - Port: ${toString config.service.port}
    
    ## Embedder
    
    - Type: ${config.embedder.type}
    - Model: ${config.embedder.model}
    
    ## Usage
    
    ```bash
    # Start the vector search service
    nix run .#serve-vectorSearchServices-${config.name}
    
    # Then use the API
    curl -X POST http://${config.service.host}:${toString config.service.port}/search \
      -H "Content-Type: application/json" \
      -d '{"query": "Your search query", "limit": 10, "threshold": 0.5}'
    ```
  '';
  
  # Create derivations
  serviceDrv = pkgs.writeScriptBin "serve-vectorSearchServices-${config.name}" serviceScript;
  docsDrv = pkgs.writeTextFile {
    name = "vectorSearchServices-${config.name}-docs";
    text = documentation;
    destination = "/share/doc/vectorSearchServices-${config.name}.md";
  };
  
  # Create a derivation that bundles everything together
  packageDrv = pkgs.symlinkJoin {
    name = "vectorSearchServices-${config.name}";
    paths = [ serviceDrv docsDrv ];
  };
  
in {
  # Original configuration
  inherit (config) name description collection;
  inherit (config) vectorDir service embedder system;
  
  # Derivations
  service = serviceDrv;
  docs = docsDrv;
  package = packageDrv;
}
