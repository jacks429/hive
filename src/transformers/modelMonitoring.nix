{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create a wrapper script to run the monitoring service
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting model monitoring: ${config.name} (${config.type})"
    
    # Parse arguments
    MODELS_DIR=""
    DATA_DIR=""
    OUTPUT_DIR=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --models-dir)
          MODELS_DIR="$2"
          shift 2
          ;;
        --data-dir)
          DATA_DIR="$2"
          shift 2
          ;;
        --output-dir)
          OUTPUT_DIR="$2"
          shift 2
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done
    
    # Check required arguments
    if [ -z "$MODELS_DIR" ] || [ -z "$DATA_DIR" ]; then
      echo "Usage: monitor-model-${config.name} --models-dir <path> --data-dir <path> [--output-dir <path>]"
      exit 1
    fi
    
    # Set default output directory if not provided
    if [ -z "$OUTPUT_DIR" ]; then
      OUTPUT_DIR="./monitoring-${config.name}-results"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${config.name}",
      "type": "${config.type}",
      "models": ${builtins.toJSON config.models},
      "metrics": ${builtins.toJSON config.metrics},
      "schedule": ${builtins.toJSON config.schedule},
      "alerts": ${builtins.toJSON config.alerts},
      "dashboard": ${builtins.toJSON config.dashboard}
    }
    EOF
    
    # Run the appropriate monitoring service based on type
    if [ "${config.type}" == "drift" ]; then
      ${pkgs.python3.withPackages (ps: with ps; [ 
        numpy pandas scikit-learn alibi-detect dash plotly 
      ])}/bin/python ${root.utils.modelMonitoring}/drift_detector.py \
        --models-dir "$MODELS_DIR" \
        --data-dir "$DATA_DIR" \
        --output-dir "$OUTPUT_DIR" \
        --config "$CONFIG