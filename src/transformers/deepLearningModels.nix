{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import shared utilities
  mlModelWrapper = import ../utils/mlModelWrapper.nix {
    inherit nixpkgs root;
  };
  
  mlServiceWrapper = import ../utils/mlServiceWrapper.nix {
    inherit nixpkgs root;
  };
  
  # Create model wrapper
  modelWrapper = mlModelWrapper config;
  
  # Create service wrapper if enabled
  serviceWrapper = if config.service.enable or false
                   then mlServiceWrapper config
                   else null;
  
  # Create training script
  trainingScript = ''
    #!/usr/bin/env python
    
    import json
    import os
    import sys
    
    # Framework-specific imports
    ${if config.framework == "pytorch" then ''
      import torch
      import torch.nn as nn
      import torch.optim as optim
      from torch.utils.data import DataLoader
    '' else if config.framework == "tensorflow" then ''
      import tensorflow as tf
      from tensorflow import keras
    '' else ''
      # Custom imports
      ${config.customImports or "# No custom imports provided"}
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
        print(json.dumps(${l.toJSON config.architecture}, indent=2))
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
            print("Usage: train-model-${config.name} <data_path> <output_path>")
            sys.exit(1)
            
        data_path = sys.argv[1]
        output_path = sys.argv[2]
        
        # Load dataset
        dataset = load_dataset(data_path)
        
        # Create model
        model = create_model()
        
        # Train model
        training_config = ${l.toJSON config.training}
        model = train_model(model, dataset, training_config)
        
        # Save model
        save_model(model, output_path)
        
        print(f"Model training complete. Model saved to {output_path}")
  '';
  
  # Create training script derivation
  trainingDrv = pkgs.writeScriptBin "train-model-${config.name}" trainingScript;
  
  # Create evaluation script
  evaluationScript = ''
    #!/usr/bin/env python
    
    import json
    import os
    import sys
    
    # Framework-specific imports
    ${if config.framework == "pytorch" then ''
      import torch
      import torch.nn as nn
      from torch.utils.data import DataLoader
    '' else if config.framework == "tensorflow" then ''
      import tensorflow as tf
      from tensorflow import keras
    '' else ''
      # Custom imports
      ${config.customImports or "# No custom imports provided"}
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
            print("Usage: evaluate-model-${config.name} <model_path> <data_path>")
            sys.exit(1)
            
        model_path = sys.argv[1]
        data_path = sys.argv[2]
        
        # Load dataset
        dataset = load_dataset(data_path)
        
        # Load model
        model = load_model(model_path)
        
        # Evaluate model
        metrics = ${l.toJSON config.metrics}
        results = evaluate_model(model, dataset, metrics)
        
        # Print results
        print("Evaluation results:")
        print(json.dumps(results, indent=2))
  '';
  
  # Create evaluation script derivation
  evaluationDrv = pkgs.writeScriptBin "evaluate-model-${config.name}" evaluationScript;
  
  # Create documentation
  documentation = ''
    # Deep Learning Model: ${config.name}
    
    ${config.description}
    
    ## Framework
    
    This model uses the **${config.framework}** framework.
    
    ## Architecture
    
    ```json
    ${builtins.toJSON config.architecture}
    ```
    
    ## Training Configuration
    
    ```json
    ${builtins.toJSON config.training}
    ```
    
    ## Evaluation Metrics
    
    ${l.concatStringsSep ", " config.metrics}
    
    ## Usage
    
    ### Train the model
    
    ```bash
    nix run .#train-model-${config.name} -- <data_path> <output_path>
    ```
    
    ### Evaluate the model
    
    ```bash
    nix run .#evaluate-model-${config.name} -- <model_path> <data_path>
    ```
    
    ### Run inference with the model
    
    ```bash
    nix run .#run-model-${config.name} -- <input_file>
    ```
    
    ${if config.service.enable then ''
    ### Start model as a service
    
    ```bash
    nix run .#serve-model-${config.name}
    ```
    
    The service will be available at http://${config.service.host or "0.0.0.0"}:${toString config.service.port}.
    
    #### API Endpoints
    
    - POST /predict - Run inference with the model
    - GET /info - Get model information
    '' else ""}
  '';
  
  # Create documentation derivation
  docsDrv = pkgs.writeTextFile {
    name = "${config.name}-docs.md";
    text = documentation;
  };
  
in {
  train = trainingDrv;
  evaluate = evaluationDrv;
  run = modelWrapper;
  serve = serviceWrapper;
  docs = docsDrv;
}
