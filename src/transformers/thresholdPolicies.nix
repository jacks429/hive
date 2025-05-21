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
  policy = transformers.withDefaults config {
    thresholds = {};
    actions = {};
  };
  
  # Generate policy script
  policyScript = transformers.withArgs {
    name = "check-threshold-${policy.name}";
    description = "Check threshold policy: ${policy.name}";
    args = [
      { name = "METRICS_FILE"; description = "Path to the metrics file to check"; required = true; position = 0; }
      { name = "OUTPUT_PATH"; description = "Path to save the policy check results"; required = false; position = 1; }
    ];
  } ''
    echo "Checking threshold policy: ${policy.name}"
    echo "Metrics file: $METRICS_FILE"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./policy-results-${policy.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${policy.name}",
      "thresholds": ${transformers.toJSON policy.thresholds},
      "actions": ${transformers.toJSON policy.actions}
    }
    EOF
    
    # Run the policy check
    ${pkgs.python3.withPackages (ps: with ps; [ 
      pyyaml
    ])}/bin/python ${root.utils.thresholdPolicy or "${pkgs.writeText "threshold_policy.py" ''
      import json
      import sys
      import os
      
      def main():
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load metrics
          metrics_path = sys.argv[2]
          print(f"Loading metrics from {metrics_path}")
          with open(metrics_path, 'r') as f:
              metrics = json.load(f)
          
          # Set output path
          output_path = sys.argv[3]
          
          # Check thresholds
          print(f"Checking thresholds for policy: {config['name']}")
          
          results = {
              "policy": config['name'],
              "violations": [],
              "actions_triggered": []
          }
          
          for metric_name, threshold in config['thresholds'].items():
              if metric_name in metrics:
                  metric_value = metrics[metric_name]
                  
                  # Check threshold type
                  if isinstance(threshold, dict):
                      # Complex threshold with min/max
                      min_value = threshold.get('min')
                      max_value = threshold.get('max')
                      
                      violation = False
                      if min_value is not None and metric_value < min_value:
                          violation = True
                          results["violations"].append({
                              "metric": metric_name,
                              "value": metric_value,
                              "threshold": f"min: {min_value}",
                              "type": "below_minimum"
                          })
                      
                      if max_value is not None and metric_value > max_value:
                          violation = True
                          results["violations"].append({
                              "metric": metric_name,
                              "value": metric_value,
                              "threshold": f"max: {max_value}",
                              "type": "above_maximum"
                          })
                  else:
                      # Simple threshold (maximum)
                      if metric_value > threshold:
                          results["violations"].append({
                              "metric": metric_name,
                              "value": metric_value,
                              "threshold": threshold,
                              "type": "above_threshold"
                          })
          
          # Determine actions
          for violation in results["violations"]:
              metric = violation["metric"]
              if metric in config["actions"]:
                  action = config["actions"][metric]
                  results["actions_triggered"].append({
                      "metric": metric,
                      "action": action
                  })
          
          # Save results
          print(f"Saving results to {output_path}")
          with open(os.path.join(output_path, 'results.json'), 'w') as f:
              json.dump(results, f, indent=2)
          
          # Generate report
          with open(os.path.join(output_path, 'report.md'), 'w') as f:
              f.write(f"# Threshold Policy Report: {config['name']}\n\n")
              
              if results["violations"]:
                  f.write(f"## Violations: {len(results['violations'])}\n\n")
                  for violation in results["violations"]:
                      f.write(f"- **{violation['metric']}**: {violation['value']} ")
                      f.write(f"({violation['type']}, threshold: {violation['threshold']})\n")
              else:
                  f.write("## Violations: None\n\n")
              
              if results["actions_triggered"]:
                  f.write(f"\n## Actions Triggered: {len(results['actions_triggered'])}\n\n")
                  for action in results["actions_triggered"]:
                      f.write(f"- **{action['metric']}**: {action['action']}\n")
              else:
                  f.write("\n## Actions Triggered: None\n\n")
          
          print("Threshold policy check completed successfully")
          
          # Exit with error if violations found
          if results["violations"]:
              print(f"Found {len(results['violations'])} threshold violations")
              sys.exit(1)
          else:
              print("No threshold violations found")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$METRICS_FILE" "$OUTPUT_PATH"
    
    # Store exit code
    EXIT_CODE=$?
    
    # Clean up
    rm "$CONFIG_FILE"
    
    if [ $EXIT_CODE -eq 0 ]; then
      echo "Threshold policy check passed. No violations found."
    else
      echo "Threshold policy check failed. Violations found. See results for details."
    fi
    
    echo "Results saved to $OUTPUT_PATH"
    exit $EXIT_CODE
  '';
  
  # Generate documentation
  policyDocs = transformers.generateDocs {
    name = "Threshold Policy: ${policy.name}";
    description = policy.description;
    usage = ''
      ```bash
      # Check metrics against threshold policy
      check-threshold-${policy.name} /path/to/metrics.json /path/to/output
      ```
    '';
    examples = ''
      ```bash
      # Example: Check model metrics against policy
      check-threshold-${policy.name} ./metrics/model_metrics.json ./results
      
      # Example: Use in a pipeline
      if check-threshold-${policy.name} ./metrics/model_metrics.json ./results; then
        echo "Policy check passed"
      else
        echo "Policy check failed"
      fi
      ```
    '';
    params = {
      thresholds = {
        description = "Threshold values for each metric";
        type = "attrset";
        value = policy.thresholds;
      };
      actions = {
        description = "Actions to take when thresholds are violated";
        type = "attrset";
        value = policy.actions;
      };
    };
  };
  
  # Create derivations
  policyDrv = transformers.mkScript {
    name = "check-threshold-${policy.name}";
    description = "Check threshold policy: ${policy.name}";
    script = policyScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${policy.name}-threshold-policy";
    content = policyDocs;
  };
  
in {
  # Original policy configuration
  inherit (policy) name description thresholds actions;
  
  # Derivations
  check = policyDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = policy.metadata or {};
}
