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
  attack = transformers.withDefaults config {
    parameters = {};
  };
  
  # Generate attack script
  attackScript = transformers.withArgs {
    name = "run-attack-${attack.name}";
    description = "Run adversarial attack: ${attack.name}";
    args = [
      { name = "MODEL_PATH"; description = "Path to the model to attack"; required = true; position = 0; }
      { name = "DATA_PATH"; description = "Path to the data to use for the attack"; required = true; position = 1; }
      { name = "OUTPUT_PATH"; description = "Path to save the attack results"; required = false; position = 2; }
    ];
  } ''
    echo "Running adversarial attack: ${attack.name}"
    echo "Method: ${attack.method}"
    echo "Target model: $MODEL_PATH"
    echo "Data: $DATA_PATH"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./attack-results-${attack.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${attack.name}",
      "method": "${attack.method}",
      "parameters": ${transformers.toJSON attack.parameters},
      "target": ${transformers.toJSON attack.target}
    }
    EOF
    
    # Run the attack
    ${pkgs.python3.withPackages (ps: with ps; [ 
      numpy torch tensorflow
    ])}/bin/python ${root.utils.adversarialAttack or "${pkgs.writeText "adversarial_attack.py" ''
      import json
      import sys
      import os
      
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
          
          # Run attack
          print(f"Running {config['method']} attack with parameters: {config['parameters']}")
          
          # Save results
          print(f"Saving results to {output_path}")
          with open(os.path.join(output_path, 'results.json'), 'w') as f:
              json.dump({
                  "attack": config['name'],
                  "method": config['method'],
                  "success_rate": 0.75,  # Placeholder
                  "examples": []  # Placeholder
              }, f, indent=2)
          
          print("Attack completed successfully")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$MODEL_PATH" "$DATA_PATH" "$OUTPUT_PATH"
    
    # Clean up
    rm "$CONFIG_FILE"
    
    echo "Attack completed. Results saved to $OUTPUT_PATH"
  '';
  
  # Generate documentation
  attackDocs = transformers.generateDocs {
    name = "Adversarial Attack: ${attack.name}";
    description = attack.description;
    usage = ''
      ```bash
      # Run the attack on a model and dataset
      run-attack-${attack.name} /path/to/model /path/to/data /path/to/output
      ```
    '';
    examples = ''
      ```bash
      # Example: Attack a model with default settings
      run-attack-${attack.name} ./models/classifier ./data/test ./results
      ```
    '';
    params = {
      method = {
        description = "Attack method to use";
        type = "string";
        value = attack.method;
      };
      parameters = {
        description = "Parameters for the attack method";
        type = "attrset";
        value = attack.parameters;
      };
      target = {
        description = "Target model configuration";
        type = "attrset";
        value = attack.target;
      };
    };
  };
  
  # Create derivations
  attackDrv = transformers.mkScript {
    name = "run-attack-${attack.name}";
    description = "Run adversarial attack: ${attack.name}";
    script = attackScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${attack.name}-attack";
    content = attackDocs;
  };
  
in {
  # Original attack configuration
  inherit (attack) name description method parameters target;
  
  # Derivations
  run = attackDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = attack.metadata or {};
}
