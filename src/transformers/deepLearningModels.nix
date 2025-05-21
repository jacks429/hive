{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Import shared utilities
  mlModelWrapper = import ../utils/mlModelWrapper.nix {
    inherit nixpkgs root;
  };
  
  mlServiceWrapper = import ../utils/mlServiceWrapper.nix {
    inherit nixpkgs root;
  };
  
  # Apply defaults to configuration
  model = transformers.withDefaults config {
    service = { enable = false; host = "0.0.0.0"; port = 8000; };
    customImports = "# No custom imports provided";
  };
  
  # Create model wrapper
  modelWrapper = mlModelWrapper model;
  
  # Create service wrapper if enabled
  serviceWrapper = if model.service.enable
                   then mlServiceWrapper model
                   else null;
  
  # Create training script using the transformers library
  trainingScript = transformers.withArgs {
    name = "train-model-${model.name}";
    description = "Train the ${model.name} deep learning model";
    args = [
      { name = "data_path"; description = "Path to the training data"; required = true; position = 0; }
      { name = "output_path"; description = "Path to save the trained model"; required = true; position = 1; }
    ];
  } ''
    # Create Python script
    SCRIPT_FILE=$(mktemp)
    cat > "$SCRIPT_FILE" << 'EOF'
    #!/usr/bin/env python
    
    import json
    import os
    import sys
    
    # Framework-specific imports
    ${if model.framework == "pytorch" then ''
      import torch
      import torch.nn as nn
      import torch.optim as optim
      from torch.utils.data import DataLoader
    '' else if model.framework == "tensorflow" then ''
      import tensorflow as tf
      from tensorflow import keras
    '' else ''
      # Custom imports
      ${model.customImports}
    ''}
    
    # Load dataset
    def load_dataset(data_path):
        # This is a placeholder - actual implementation would depend on the dataset format
        print(f"Loading dataset from {data_path}")
        return "dataset"
    
    # Define model
    def create_model():
        # This is a placeholder - actual implementation would depend on the model architecture
        print("Creating model with architecture:")
        print(json.dumps(${transformers.toJSON model.architecture}, indent=2))
        return "model"
    
    # Train model
    def train_model(model, dataset, config):
        # This is a placeholder - actual implementation would depend on the framework
        print("Training model with config:")
        print(json.dumps(config, indent=2))
        return model
    
    # Save model
    def save_model(model, output_path):
        # This is a placeholder - actual implementation would depend on the framework
        print(f"Saving model to {output_path}")
    
    # Main execution
    if __name__ == "__main__":
        # Parse arguments
        if len(sys.argv) < 3:
            print("Usage: train-model-${model.name} <data_path> <output_path>")
            sys.exit(1)
            
        data_path = sys.argv[1]
        output_path = sys.argv[2]
        
        # Load dataset
        dataset = load_dataset(data_path)
        
        # Create model
        model = create_model()
        
        # Train model
        training_config = ${transformers.toJSON model.training}
        model = train_model(model, dataset, training_config)
        
        # Save model
        save_model(model, output_path)
        
        print(f"Model training complete. Model saved to {output_path}")
    EOF
    
    # Run the script
    ${pkgs.python3}/bin/python "$SCRIPT_FILE" "$data_path" "$output_path"
    
    # Clean up
    rm "$SCRIPT_FILE"
  '';
  
  # Create evaluation script using the transformers library
  evaluationScript = transformers.withArgs {
    name = "evaluate-model-${model.name}";
    description = "Evaluate the ${model.name} deep learning model";
    args = [
      { name = "model_path"; description = "Path to the trained model"; required = true; position = 0; }
      { name = "data_path"; description = "Path to the evaluation data"; required = true; position = 1; }
    ];
  } ''
    # Create Python script
    SCRIPT_FILE=$(mktemp)
    cat > "$SCRIPT_FILE" << 'EOF'
    #!/usr/bin/env python
    
    import json
    import os
    import sys
    
    # Framework-specific imports
    ${if model.framework == "pytorch" then ''
      import torch
      import torch.nn as nn
      from torch.utils.data import DataLoader
    '' else if model.framework == "tensorflow" then ''
      import tensorflow as tf
      from tensorflow import keras
    '' else ''
      # Custom imports
      ${model.customImports}
    ''}
    
    # Load dataset
    def load_dataset(data_path):
        # This is a placeholder - actual implementation would depend on the dataset format
        print(f"Loading dataset from {data_path}")
        return "dataset"
    
    # Load model
    def load_model(model_path):
        # This is a placeholder - actual implementation would depend on the framework
        print(f"Loading model from {model_path}")
        return "model"
    
    # Evaluate model
    def evaluate_model(model, dataset, metrics):
        # This is a placeholder - actual implementation would depend on the framework
        print(f"Evaluating model with metrics: {metrics}")
        results = {metric: 0.9 for metric in metrics}  # Dummy results
        return results
    
    # Main execution
    if __name__ == "__main__":
        # Parse arguments
        if len(sys.argv) < 3:
            print("Usage: evaluate-model-${model.name} <model_path> <data_path>")
            sys.exit(1)
            
        model_path = sys.argv[1]
        data_path = sys.argv[2]
        
        # Load dataset
        dataset = load_dataset(data_path)
        
        # Load model
        model = load_model(model_path)
        
        # Evaluate model
        metrics = ${transformers.toJSON model.metrics}
        results = evaluate_model(model, dataset, metrics)
        
        # Print results
        print("Evaluation results:")
        print(json.dumps(results, indent=2))
    EOF
    
    # Run the script
    ${pkgs.python3}/bin/python "$SCRIPT_FILE" "$model_path" "$data_path"
    
    # Clean up
    rm "$SCRIPT_FILE"
  '';
  
  # Generate documentation using the transformers library
  modelDocs = transformers.generateDocs {
    name = "Deep Learning Model: ${model.name}";
    description = model.description;
    usage = ''
      ```bash
      # Train the model
      train-model-${model.name} <data_path> <output_path>
      
      # Evaluate the model
      evaluate-model-${model.name} <model_path> <data_path>
      
      # Run inference with the model
      run-model-${model.name} <input_file>
      
      ${if model.service.enable then ''
      # Start model as a service
      serve-model-${model.name}
      ''' else ""}
      ```
    '';
    examples = ''
      ```bash
      # Train a model on a dataset
      train-model-${model.name} ./data/training ./models/${model.name}
      
      # Evaluate the trained model
      evaluate-model-${model.name} ./models/${model.name} ./data/validation
      
      # Run inference on a file
      echo "Input data" | run-model-${model.name}
      ```
    '';
    params = {
      framework = {
        description = "Deep learning framework used by the model";
        type = "string";
        value = model.framework;
      };
      architecture = {
        description = "Model architecture configuration";
        type = "attrset";
        value = model.architecture;
      };
      training = {
        description = "Training configuration";
        type = "attrset";
        value = model.training;
      };
      metrics = {
        description = "Evaluation metrics";
        type = "list";
        value = model.metrics;
      };
    };
  };
  
  # Create derivations using the transformers library
  trainingDrv = transformers.mkScript {
    name = "train-model-${model.name}";
    description = "Train the ${model.name} deep learning model";
    script = trainingScript;
  };
  
  evaluationDrv = transformers.mkScript {
    name = "evaluate-model-${model.name}";
    description = "Evaluate the ${model.name} deep learning model";
    script = evaluationScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${model.name}";
    content = modelDocs;
  };
  
in {
  # Original model configuration
  inherit (model) name description framework architecture training metrics;
  
  # Derivations
  train = trainingDrv;
  evaluate = evaluationDrv;
  run = modelWrapper;
  serve = serviceWrapper;
  docs = docsDrv;
}
