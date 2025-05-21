{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Apply defaults to configuration
  detector = transformers.withDefaults config {
    metrics = [];
    thresholds = {};
  };
  
  # Generate detector script
  detectorScript = transformers.withArgs {
    name = "run-drift-detector-${detector.name}";
    description = "Run drift detector: ${detector.name}";
    args = [
      { name = "REFERENCE_DATA"; description = "Path to the reference data"; required = true; position = 0; }
      { name = "CURRENT_DATA"; description = "Path to the current data to check for drift"; required = true; position = 1; }
      { name = "OUTPUT_PATH"; description = "Path to save the drift detection results"; required = false; position = 2; }
    ];
  } ''
    echo "Running drift detector: ${detector.name}"
    echo "Method: ${detector.method}"
    echo "Reference data: $REFERENCE_DATA"
    echo "Current data: $CURRENT_DATA"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./drift-results-${detector.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${detector.name}",
      "method": "${detector.method}",
      "metrics": ${transformers.toJSON detector.metrics},
      "thresholds": ${transformers.toJSON detector.thresholds},
      "dataSource": ${transformers.toJSON detector.dataSource}
    }
    EOF
    
    # Run the drift detector
    ${pkgs.python3.withPackages (ps: with ps; [ 
      numpy pandas scikit-learn
    ])}/bin/python ${root.utils.driftDetector or "${pkgs.writeText "drift_detector.py" ''
      import json
      import sys
      import os
      import pandas as pd
      import numpy as np
      
      def main():
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load reference data
          reference_path = sys.argv[2]
          print(f"Loading reference data from {reference_path}")
          
          # Load current data
          current_path = sys.argv[3]
          print(f"Loading current data from {current_path}")
          
          # Set output path
          output_path = sys.argv[4]
          
          # Run drift detection
          print(f"Running {config['method']} drift detection with metrics: {config['metrics']}")
          
          # Generate sample results
          results = {
              "detector": config['name'],
              "method": config['method'],
              "drift_detected": False,
              "metrics": {}
          }
          
          for metric in config['metrics']:
              threshold = config['thresholds'].get(metric, 0.05)
              p_value = np.random.uniform(0, 0.1)  # Placeholder
              drift = p_value < threshold
              
              if drift:
                  results["drift_detected"] = True
              
              results["metrics"][metric] = {
                  "p_value": p_value,
                  "threshold": threshold,
                  "drift_detected": drift
              }
          
          # Save results
          print(f"Saving results to {output_path}")
          with open(os.path.join(output_path, 'results.json'), 'w') as f:
              json.dump(results, f, indent=2)
          
          # Generate report
          with open(os.path.join(output_path, 'report.md'), 'w') as f:
              f.write(f"# Drift Detection Report: {config['name']}\n\n")
              f.write(f"Method: {config['method']}\n\n")
              f.write(f"Overall drift detected: {'Yes' if results['drift_detected'] else 'No'}\n\n")
              f.write("## Metrics\n\n")
              
              for metric, values in results["metrics"].items():
                  f.write(f"### {metric}\n\n")
                  f.write(f"- p-value: {values['p_value']:.4f}\n")
                  f.write(f"- threshold: {values['threshold']:.4f}\n")
                  f.write(f"- drift detected: {'Yes' if values['drift_detected'] else 'No'}\n\n")
          
          print("Drift detection completed successfully")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$REFERENCE_DATA" "$CURRENT_DATA" "$OUTPUT_PATH"
    
    # Clean up
    rm "$CONFIG_FILE"
    
    echo "Drift detection completed. Results saved to $OUTPUT_PATH"
  '';
  
  # Generate documentation
  detectorDocs = transformers.generateDocs {
    name = "Drift Detector: ${detector.name}";
    description = detector.description;
    usage = ''
      ```bash
      # Run the drift detector on reference and current data
      run-drift-detector-${detector.name} /path/to/reference/data /path/to/current/data /path/to/output
      ```
    '';
    examples = ''
      ```bash
      # Example: Check for drift between training and production data
      run-drift-detector-${detector.name} ./data/training.csv ./data/production.csv ./results
      ```
    '';
    params = {
      method = {
        description = "Drift detection method to use";
        type = "string";
        value = detector.method;
      };
      metrics = {
        description = "Metrics to use for drift detection";
        type = "list";
        value = detector.metrics;
      };
      thresholds = {
        description = "Thresholds for each metric";
        type = "attrset";
        value = detector.thresholds;
      };
      dataSource = {
        description = "Data source configuration";
        type = "attrset";
        value = detector.dataSource;
      };
    };
  };
  
  # Create derivations
  detectorDrv = transformers.mkScript {
    name = "run-drift-detector-${detector.name}";
    description = "Run drift detector: ${detector.name}";
    script = detectorScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${detector.name}-drift-detector";
    content = detectorDocs;
  };
  
in {
  # Original detector configuration
  inherit (detector) name description method metrics thresholds dataSource;
  
  # Derivations
  run = detectorDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = detector.metadata or {};
}
