{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create a wrapper script to run the classifier
  runnerScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running classifier: ${config.name}"
    
    # Parse arguments
    INPUT_FILE=""
    OUTPUT_FILE=""
    
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
      "params": ${builtins.toJSON config.params}
    }
    EOF
    
    # Run the classifier
    ${pkgs.python3.withPackages (ps: with ps; [ 
      transformers torch numpy scikit-learn
    ])}/bin/python ${root.utils.modelRunner}/classifier_runner.py \
      --model-uri "${config.modelUri}" \
      --input "$INPUT_FILE" \
      --output "$OUTPUT_FILE" \
      --config "$CONFIG_FILE"
    
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
  
  # Create the runner script derivation
  runnerDrv = pkgs.writeScriptBin "run-classifier-${config.name}" runnerScript;
  
in runnerDrv