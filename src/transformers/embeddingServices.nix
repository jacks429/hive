{ inputs, nixpkgs, root }:
config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create a wrapper script to run the embedding model
  runnerScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running embedding service: ${config.meta.name}"
    
    # Parse arguments
    INPUT_FILE=""
    OUTPUT_FILE=""
    MODE="encode"
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --input)
          INPUT_FILE="$2"
          shift 2
          ;;
        --output)
          OUTPUT_FILE="$2"
          shift 2
          ;;
        --mode)
          MODE="$2"
          shift 2
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done
    
    # Handle stdin/stdout if no files specified
    if [ -z "$INPUT_FILE" ]; then
      INPUT_FILE=$(mktemp)
      cat > "$INPUT_FILE"
      REMOVE_INPUT=1
    fi
    
    if [ -z "$OUTPUT_FILE" ]; then
      OUTPUT_FILE=$(mktemp)
      REMOVE_OUTPUT=1
    fi
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "modelUri": "${config.modelUri}",
      "framework": "${config.framework}",
      "params": ${builtins.toJSON config.params},
      "mode": "$MODE"
    }
    EOF
    
    # Run the embedding model
    ${pkgs.python3.withPackages (ps: with ps; [ 
      transformers torch numpy sentence-transformers
    ])}/bin/python ${root.utils.modelRunner}/embedding_runner.py \
      --model-uri "${config.modelUri}" \
      --input "$INPUT_FILE" \
      --output "$OUTPUT_FILE" \
      --config "$CONFIG_FILE" \
      --mode "$MODE"
    
    # Output results
    if [ -n "$REMOVE_OUTPUT" ]; then
      cat "$OUTPUT_FILE"
      rm "$OUTPUT_FILE"
    fi
    
    # Clean up
    if [ -n "$REMOVE_INPUT" ]; then
      rm "$INPUT_FILE"
    fi
    
    rm "$CONFIG_FILE"
  '';
  
  # Create service script
  serviceScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting embedding service: ${config.meta.name}"
    echo "Listening on ${config.service.host}:${toString config.service.port}"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "modelUri": "${config.modelUri}",
      "framework": "${config.framework}",
      "params": ${builtins.toJSON config.params},
      "service": {
        "host": "${config.service.host}",
        "port": ${toString config.service.port}
      }
    }
    EOF
    
    # Run the embedding service
    ${pkgs.python3.withPackages (ps: with ps; [ 
      fastapi uvicorn transformers torch numpy sentence-transformers
    ])}/bin/python ${root.utils.modelService}/embedding_service.py \
      --model-uri "${config.modelUri}" \
      --framework "${config.framework}" \
      --host "${config.service.host}" \
      --port "${toString config.service.port}" \
      --config "$CONFIG_FILE"
      
    # Clean up
    rm "$CONFIG_FILE"
  '';
  
  # Create documentation
  documentation = ''
    # Embedding Service: ${config.meta.name}
    
    ${config.meta.description}
    
    ## Framework
    
    This embedding model uses the **${config.framework}** framework.
    
    ## Parameters
    
    ```json
    ${builtins.toJSON config.params}
    ```
    
    ## Usage
    
    ### Encode text to embeddings
    
    ```bash
    # Encode text from stdin
    echo "Text to encode" | nix run .#run-embeddingServices-${config.meta.name} -- --mode encode
    
    # Encode text from file
    nix run .#run-embeddingServices-${config.meta.name} -- --input input.txt --output embeddings.json --mode encode
    ```
    
    ### Start as a service
    
    ```bash
    nix run .#serve-embeddingServices-${config.meta.name}
    
    # Then use the API
    curl -X POST http://${config.service.host}:${toString config.service.port}/encode \
      -H "Content-Type: application/json" \
      -d '{"text": "Text to encode"}'
    
    # Batch encoding
    curl -X POST http://${config.service.host}:${toString config.service.port}/encode-batch \
      -H "Content-Type: application/json" \
      -d '{"texts": ["Text 1", "Text 2", "Text 3"]}'
    
    # Similarity calculation
    curl -X POST http://${config.service.host}:${toString config.service.port}/similarity \
      -H "Content-Type: application/json" \
      -d '{"text1": "First text", "text2": "Second text"}'
    ```
  '';
  
  # Create derivations
  runnerDrv = pkgs.writeScriptBin "run-embeddingServices-${config.meta.name}" runnerScript;
  serviceDrv = pkgs.writeScriptBin "serve-embeddingServices-${config.meta.name}" serviceScript;
  docsDrv = pkgs.writeTextFile {
    name = "embeddingServices-${config.meta.name}-docs";
    text = documentation;
    destination = "/share/doc/embeddingServices-${config.meta.name}.md";
  };
  
  # Create a derivation that bundles everything together
  packageDrv = pkgs.symlinkJoin {
    name = "embeddingServices-${config.meta.name}";
    paths = [ runnerDrv serviceDrv docsDrv ];
  };
  
in {
  # Original model configuration
  inherit (config) modelUri framework params;
  inherit (config) meta service system;
  
  # Derivations
  runner = runnerDrv;
  service = serviceDrv;
  docs = docsDrv;
  package = packageDrv;
}