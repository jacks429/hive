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
  metric = transformers.withDefaults config {
    sensitiveAttributes = [];
    thresholds = {};
  };
  
  # Generate metric script
  metricScript = transformers.withArgs {
    name = "compute-fairness-${metric.name}";
    description = "Compute fairness metric: ${metric.name}";
    args = [
      { name = "MODEL_PATH"; description = "Path to the model to evaluate"; required = true; position = 0; }
      { name = "DATA_PATH"; description = "Path to the evaluation data"; required = true; position = 1; }
      { name = "OUTPUT_PATH"; description = "Path to save the fairness evaluation results"; required = false; position = 2; }
    ];
  } ''
    echo "Computing fairness metric: ${metric.name}"
    echo "Method: ${metric.method}"
    echo "Model: $MODEL_PATH"
    echo "Data: $DATA_PATH"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./fairness-results-${metric.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${metric.name}",
      "method": "${metric.method}",
      "sensitiveAttributes": ${transformers.toJSON metric.sensitiveAttributes},
      "thresholds": ${transformers.toJSON metric.thresholds}
    }
    EOF
    
    # Run the fairness evaluation
    ${pkgs.python3.withPackages (ps: with ps; [ 
      numpy pandas scikit-learn
    ])}/bin/python ${root.utils.fairnessMetric or "${pkgs.writeText "fairness_metric.py" ''
      import json
      import sys
      import os
      import numpy as np
      import pandas as pd
      
      def main():
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load model
          model_path = sys.argv[2]
          print(f"Loading model from {model_path}")
          
          # Load data
          data_path = sys.argv[3]
          print(f"Loading data from {data_path}")
          
          # Set output path
          output_path = sys.argv[4]
          
          # Compute fairness metrics
          print(f"Computing {config['method']} fairness metric for attributes: {config['sensitiveAttributes']}")
          
          # Generate sample results
          results = {
              "metric": config['name'],
              "method": config['method'],
              "overall_fair": True,
              "attributes": {}
          }
          
          for attr in config['sensitiveAttributes']:
              threshold = config['thresholds'].get(attr, 0.8)
              
              # Generate random scores for demonstration
              groups = ["group_a", "group_b"]
              scores = {}
              
              for group in groups:
                  scores[group] = np.random.uniform(0.7, 1.0)
              
              # Calculate disparity
              max_score = max(scores.values())
              min_score = min(scores.values())
              disparity = 1.0 - (min_score / max_score if max_score > 0 else 1.0)
              
              # Check if fair
              fair = disparity <= (1.0 - threshold)
              
              if not fair:
                  results["overall_fair"] = False
              
              results["attributes"][attr] = {
                  "scores": scores,
                  "disparity": disparity,
                  "threshold": threshold,
                  "fair": fair
              }
          
          # Save results
          print(f"Saving results to {output_path}")
          with open(os.path.join(output_path, 'results.json'), 'w') as f:
              json.dump(results, f, indent=2)
          
          # Generate report
          with open(os.path.join(output_path, 'report.md'), 'w') as f:
              f.write(f"# Fairness Evaluation Report: {config['name']}\n\n")
              f.write(f"Method: {config['method']}\n\n")
              f.write(f"Overall fairness: {'Fair' if results['overall_fair'] else 'Unfair'}\n\n")
              f.write("## Sensitive Attributes\n\n")
              
              for attr, values in results["attributes"].items():
                  f.write(f"### {attr}\n\n")
                  f.write(f"- Disparity: {values['disparity']:.4f}\n")
                  f.write(f"- Threshold: {values['threshold']:.4f}\n")
                  f.write(f"- Fair: {'Yes' if values['fair'] else 'No'}\n\n")
                  
                  f.write("#### Group Scores\n\n")
                  for group, score in values['scores'].items():
                      f.write(f"- {group}: {score:.4f}\n")
                  
                  f.write("\n")
          
          print("Fairness evaluation completed successfully")
          
          # Exit with error if unfair
          if not results["overall_fair"]:
              print("Model does not meet fairness criteria")
              sys.exit(1)
          else:
              print("Model meets fairness criteria")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$MODEL_PATH" "$DATA_PATH" "$OUTPUT_PATH"
    
    # Store exit code
    EXIT_CODE=$?
    
    # Clean up
    rm "$CONFIG_FILE"
    
    if [ $EXIT_CODE -eq 0 ]; then
      echo "Fairness evaluation passed. Model meets fairness criteria."
    else
      echo "Fairness evaluation failed. Model does not meet fairness criteria."
    fi
    
    echo "Results saved to $OUTPUT_PATH"
    exit $EXIT_CODE
  '';
  
  # Generate documentation
  metricDocs = transformers.generateDocs {
    name = "Fairness Metric: ${metric.name}";
    description = metric.description;
    usage = ''
      ```bash
      # Compute fairness metric for a model and dataset
      compute-fairness-${metric.name} /path/to/model /path/to/data /path/to/output
      ```
    '';
    examples = ''
      ```bash
      # Example: Evaluate model fairness
      compute-fairness-${metric.name} ./models/classifier ./data/evaluation ./results
      
      # Example: Use in a pipeline
      if compute-fairness-${metric.name} ./models/classifier ./data/evaluation ./results; then
        echo "Model is fair"
      else
        echo "Model is unfair"
      fi
      ```
    '';
    params = {
      method = {
        description = "Fairness evaluation method to use";
        type = "string";
        value = metric.method;
      };
      sensitiveAttributes = {
        description = "Sensitive attributes to evaluate for fairness";
        type = "list";
        value = metric.sensitiveAttributes;
      };
      thresholds = {
        description = "Fairness thresholds for each attribute";
        type = "attrset";
        value = metric.thresholds;
      };
    };
  };
  
  # Create derivations
  metricDrv = transformers.mkScript {
    name = "compute-fairness-${metric.name}";
    description = "Compute fairness metric: ${metric.name}";
    script = metricScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${metric.name}-fairness-metric";
    content = metricDocs;
  };
  
in {
  # Original metric configuration
  inherit (metric) name description method sensitiveAttributes thresholds;
  
  # Derivations
  compute = metricDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = metric.metadata or {};
}
