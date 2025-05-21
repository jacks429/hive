{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create a wrapper script that calls the appropriate validator
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running data validation: ${config.name} (${config.type})"
    
    # Parse arguments
    DATA_PATH=""
    OUTPUT_PATH=""
    CONFIG_PATH=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --data-path)
          DATA_PATH="$2"
          shift 2
          ;;
        --output-path)
          OUTPUT_PATH="$2"
          shift 2
          ;;
        --config)
          CONFIG_PATH="$2"
          shift 2
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done
    
    # Check required arguments
    if [ -z "$DATA_PATH" ]; then
      echo "Usage: validate-data-${config.name} --data-path <path> [--output-path <path>] [--config <path>]"
      exit 1
    fi
    
    # Set default output path if not provided
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./validation-${config.name}-results"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_PATH"
    
    # Create temporary config file with validation rules
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${config.name}",
      "type": "${config.type}",
      "expectations": ${builtins.toJSON config.expectations},
      "rules": ${builtins.toJSON config.rules},
      "onFailure": ${builtins.toJSON config.onFailure}
    }
    EOF
    
    # Run the appropriate validator based on type
    if [ "${config.type}" == "great-expectations" ]; then
      ${pkgs.python3.withPackages (ps: with ps; [ great-expectations pandas ])}/bin/python ${root.utils.dataValidationScripts}/great_expectations_validator.py \
        --data-path "$DATA_PATH" \
        --output-path "$OUTPUT_PATH" \
        --config "$CONFIG_FILE"
    elif [ "${config.type}" == "deequ" ]; then
      ${pkgs.jre}/bin/java -jar ${root.utils.dataValidationScripts}/deequ-validator.jar \
        --data-path "$DATA_PATH" \
        --output-path "$OUTPUT_PATH" \
        --config "$CONFIG_FILE"
    elif [ "${config.type}" == "custom" ]; then
      # For custom validators, use the provided script
      if [ -z "$CONFIG_PATH" ]; then
        echo "Error: Custom validator requires a config path"
        exit 1
      fi
      ${pkgs.python3}/bin/python "$CONFIG_PATH" \
        --data-path "$DATA_PATH" \
        --output-path "$OUTPUT_PATH" \
        --config "$CONFIG_FILE"
    else
      echo "Error: Unsupported validator type: ${config.type}"
      exit 1
    fi
    
    # Clean up
    rm "$CONFIG_FILE"
    
    # Check if validation passed
    if [ -f "$OUTPUT_PATH/validation_result.json" ]; then
      VALIDATION_PASSED=$(jq '.passed' "$OUTPUT_PATH/validation_result.json")
      if [ "$VALIDATION_PASSED" == "true" ]; then
        echo "Validation passed!"
        exit 0
      else
        echo "Validation failed. See $OUTPUT_PATH/validation_result.json for details."
        
        # Handle failure action
        if [ "${config.onFailure.action}" == "fail" ]; then
          exit 1
        elif [ "${config.onFailure.action}" == "alert" ]; then
          # Send alerts (placeholder)
          echo "Sending alerts..."
        fi
      fi
    else
      echo "Error: Validation result file not found"
      exit 1
    fi
  '';
  
  # Create wrapper script derivation
  wrapperDrv = pkgs.writeScriptBin "validate-data-${config.name}" wrapperScript;
  
  # Create documentation
  documentation = ''
    # Data Validator: ${config.name}
    
    ${config.description}
    
    ## Type
    
    This validator uses the **${config.type}** validation framework.
    
    ## Data Source
    
    - Type: ${config.dataSource.type}
    ${if config.dataSource ? path then "- Path: ${config.dataSource.path}" else ""}
    
    ## Validation Rules
    
    ${if config.rules != [] then builtins.toJSON config.rules else "No specific rules defined."}
    
    ## Expectations
    
    ${if config.expectations != [] then builtins.toJSON config.expectations else "No specific expectations defined."}
    
    ## On Failure
    
    - Action: ${config.onFailure.action}
    ${if config.onFailure.action == "alert" then "- Alert Channels: ${builtins.toJSON config.onFailure.alertChannels}" else ""}
    
    ## Usage
    
    ```bash
    nix run .#validate-data-${config.name} -- \
      --data-path <path-to-data> \
      --output-path <path-to-save-results> \
      --config <optional-config-file>
    ```
  '';
  
  # Create documentation derivation
  docsDrv = pkgs.writeTextFile {
    name = "${config.name}-docs.md";
    text = documentation;
  };
  
in {
  validate = wrapperDrv;
  docs = docsDrv;
}
