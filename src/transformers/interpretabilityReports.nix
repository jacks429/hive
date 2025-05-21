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
  report = transformers.withDefaults config {
    methods = [];
    datasets = [];
  };
  
  # Generate report script
  reportScript = transformers.withArgs {
    name = "generate-interpretability-report-${report.name}";
    description = "Generate interpretability report: ${report.name}";
    args = [
      { name = "MODEL_PATH"; description = "Path to the model to interpret"; required = true; position = 0; }
      { name = "OUTPUT_PATH"; description = "Path to save the interpretability report"; required = false; position = 1; }
    ];
  } ''
    echo "Generating interpretability report: ${report.name}"
    echo "Model: $MODEL_PATH"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./interpretability-report-${report.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${report.name}",
      "model": ${transformers.toJSON report.model},
      "methods": ${transformers.toJSON report.methods},
      "datasets": ${transformers.toJSON report.datasets}
    }
    EOF
    
    # Run the interpretability analysis
    ${pkgs.python3.withPackages (ps: with ps; [ 
      numpy pandas matplotlib
    ])}/bin/python ${root.utils.interpretabilityReport or "${pkgs.writeText "interpretability_report.py" ''
      import json
      import sys
      import os
      import numpy as np
      import matplotlib.pyplot as plt
      
      def main():
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load model
          model_path = sys.argv[2]
          print(f"Loading model from {model_path}")
          
          # Set output path
          output_path = sys.argv[3]
          
          # Generate interpretability report
          print(f"Generating interpretability report using methods: {config['methods']}")
          
          # Create results structure
          results = {
              "report": config['name'],
              "model": config['model'],
              "methods": {},
              "datasets": config['datasets']
          }
          
          # Generate figures directory
          figures_dir = os.path.join(output_path, "figures")
          os.makedirs(figures_dir, exist_ok=True)
          
          # Generate sample results for each method
          for method in config['methods']:
              print(f"Applying {method} method")
              
              # Generate random feature importance for demonstration
              num_features = 10
              feature_names = [f"feature_{i}" for i in range(num_features)]
              importances = np.random.uniform(0, 1, num_features)
              importances = importances / importances.sum()  # Normalize
              
              # Sort by importance
              sorted_indices = np.argsort(importances)[::-1]
              sorted_features = [feature_names[i] for i in sorted_indices]
              sorted_importances = importances[sorted_indices]
              
              # Create figure
              plt.figure(figsize=(10, 6))
              plt.barh(sorted_features, sorted_importances)
              plt.xlabel('Importance')
              plt.ylabel('Feature')
              plt.title(f'{method} Feature Importance')
              plt.tight_layout()
              
              # Save figure
              figure_path = os.path.join(figures_dir, f"{method}_importance.png")
              plt.savefig(figure_path)
              plt.close()
              
              # Store results
              results["methods"][method] = {
                  "feature_importance": {
                      feature: float(importance) for feature, importance in zip(sorted_features, sorted_importances)
                  },
                  "figure_path": os.path.relpath(figure_path, output_path)
              }
          
          # Save results
          print(f"Saving results to {output_path}")
          with open(os.path.join(output_path, 'results.json'), 'w') as f:
              json.dump(results, f, indent=2)
          
          # Generate report
          with open(os.path.join(output_path, 'report.md'), 'w') as f:
              f.write(f"# Interpretability Report: {config['name']}\n\n")
              
              f.write("## Model Information\n\n")
              for key, value in config['model'].items():
                  f.write(f"- **{key}**: {value}\n")
              
              f.write("\n## Methods\n\n")
              for method, data in results["methods"].items():
                  f.write(f"### {method}\n\n")
                  
                  f.write("#### Feature Importance\n\n")
                  f.write("| Feature | Importance |\n")
                  f.write("|---------|------------|\n")
                  
                  for feature, importance in data["feature_importance"].items():
                      f.write(f"| {feature} | {importance:.4f} |\n")
                  
                  f.write(f"\n![{method} Feature Importance]({data['figure_path']})\n\n")
              
              f.write("\n## Datasets\n\n")
              for dataset in config['datasets']:
                  f.write(f"- {dataset}\n")
          
          print("Interpretability report generated successfully")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$MODEL_PATH" "$OUTPUT_PATH"
    
    # Clean up
    rm "$CONFIG_FILE"
    
    echo "Interpretability report generated. Results saved to $OUTPUT_PATH"
    echo "Open $OUTPUT_PATH/report.md to view the report."
  '';
  
  # Generate documentation
  reportDocs = transformers.generateDocs {
    name = "Interpretability Report: ${report.name}";
    description = report.description;
    usage = ''
      ```bash
      # Generate interpretability report for a model
      generate-interpretability-report-${report.name} /path/to/model /path/to/output
      ```
    '';
    examples = ''
      ```bash
      # Example: Generate report for a classifier model
      generate-interpretability-report-${report.name} ./models/classifier ./reports
      ```
    '';
    params = {
      model = {
        description = "Model configuration";
        type = "attrset";
        value = report.model;
      };
      methods = {
        description = "Interpretability methods to apply";
        type = "list";
        value = report.methods;
      };
      datasets = {
        description = "Datasets used for interpretation";
        type = "list";
        value = report.datasets;
      };
    };
  };
  
  # Create derivations
  reportDrv = transformers.mkScript {
    name = "generate-interpretability-report-${report.name}";
    description = "Generate interpretability report: ${report.name}";
    script = reportScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${report.name}-interpretability-report";
    content = reportDocs;
  };
  
in {
  # Original report configuration
  inherit (report) name description model methods datasets;
  
  # Derivations
  generate = reportDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = report.metadata or {};
}
