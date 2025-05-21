{
  nixpkgs,
  root,
}: model: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${model.system};
  
  # Create a wrapper script to run the model
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running model: ${model.name} (${model.framework})"
    
    # Parse arguments
    INPUT_PATH=""
    OUTPUT_PATH=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --input)
          INPUT_PATH="$2"
          shift 2
          ;;
        --output)
          OUTPUT_PATH="$2"
          shift 2
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done
    
    # Check required arguments
    if [ -z "$INPUT_PATH" ]; then
      echo "Usage: run-model-${model.name} --input <path> [--output <path>]"
      exit 1
    fi
    
    # Set default output path if not provided
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./output.json"
    fi
    
    # Create temporary model config
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${model.name}",
      "framework": "${model.framework}",
      "architecture": ${builtins.toJSON model.architecture},
      "params": ${builtins.toJSON model.params}
    }
    EOF
    
    # Run the appropriate model runner based on framework
    if [ "${model.framework}" == "pytorch" ]; then
      ${pkgs.python3.withPackages (ps: with ps; [ pytorch torchvision ])}/bin/python ${root.utils.modelRunners}/pytorch_runner.py \
        --input "$INPUT_PATH" \
        --output "$OUTPUT_PATH" \
        --config "$CONFIG_FILE" \
        ${if model.customLoadModel != null then "--custom-loader ${model.customLoadModel}" else ""} \
        ${if model.customInference != null then "--custom-inference ${model.customInference}" else ""}
    elif [ "${model.framework}" == "tensorflow" ]; then
      ${pkgs.python3.withPackages (ps: with ps; [ tensorflow ])}/bin/python ${root.utils.modelRunners}/tensorflow_runner.py \
        --input "$INPUT_PATH" \
        --output "$OUTPUT_PATH" \
        --config "$CONFIG_FILE" \
        ${if model.customLoadModel != null then "--custom-loader ${model.customLoadModel}" else ""} \
        ${if model.customInference != null then "--custom-inference ${model.customInference}" else ""}
    else
      # For custom frameworks, use the provided custom imports and code
      ${pkgs.python3}/bin/python ${root.utils.modelRunners}/generic_runner.py \
        --input "$INPUT_PATH" \
        --output "$OUTPUT_PATH" \
        --config "$CONFIG_FILE" \
        ${if model.customImports != null then "--custom-imports ${model.customImports}" else ""} \
        ${if model.customLoadModel != null then "--custom-loader ${model.customLoadModel}" else ""} \
        ${if model.customInference != null then "--custom-inference ${model.customInference}" else ""}
    fi
    
    # Clean up
    rm "$CONFIG_FILE"
    
    echo "Model inference complete. Results saved to $OUTPUT_PATH"
  '';
  
  # Create wrapper script derivation
  wrapperDrv = pkgs.writeScriptBin "run-model-${model.name}" wrapperScript;
  
in wrapperDrv
