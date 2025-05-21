{
  nixpkgs,
  root,
  inputs,
}: model: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${model.system};
  
  # Framework-specific model loaders
  frameworkLoaders = {
    "huggingface" = ''
      from transformers import AutoModel, AutoTokenizer, pipeline
      import sys
      import json
      
      def load_model(model_path, task):
          return pipeline(task, model=model_path)
      
      # Load the model based on task
      model = load_model("${model.modelUri}", "${model.task}")
      
      # Process input
      input_text = sys.stdin.read().strip() if len(sys.argv) <= 1 else open(sys.argv[1]).read().strip()
      result = model(input_text)
      
      # Output result
      print(json.dumps(result, indent=2))
    '';
    
    "spacy" = ''
      import spacy
      import sys
      import json
      
      def load_model(model_path):
          return spacy.load(model_path)
      
      # Load the model
      nlp = load_model("${model.modelUri}")
      
      # Process input
      input_text = sys.stdin.read().strip() if len(sys.argv) <= 1 else open(sys.argv[1]).read().strip()
      doc = nlp(input_text)
      
      # Process based on task type
      result = ${model.processExpr or "doc.to_json()"}
      
      # Output result
      print(json.dumps(result, indent=2))
    '';
    
    "pytorch" = ''
      import torch
      import sys
      import json
      
      # Custom model loading code
      ${model.loadExpr or "# No custom load expression provided"}
      
      # Process input
      input_text = sys.stdin.read().strip() if len(sys.argv) <= 1 else open(sys.argv[1]).read().strip()
      
      # Process with model
      result = ${model.processExpr or "# No process expression provided"}
      
      # Output result
      print(json.dumps(result, indent=2))
    '';
    
    "tensorflow" = ''
      import tensorflow as tf
      import sys
      import json
      
      # Custom model loading code
      ${model.loadExpr or "# No custom load expression provided"}
      
      # Process input
      input_text = sys.stdin.read().strip() if len(sys.argv) <= 1 else open(sys.argv[1]).read().strip()
      
      # Process with model
      result = ${model.processExpr or "# No process expression provided"}
      
      # Output result
      print(json.dumps(result, indent=2))
    '';
    
    "generic" = ''
      # Generic model loading code
      import sys
      import json
      
      ${model.loadExpr or "# No custom load expression provided"}
      
      # Process input
      input_text = sys.stdin.read().strip() if len(sys.argv) <= 1 else open(sys.argv[1]).read().strip()
      
      # Process with model
      result = ${model.processExpr or "# No process expression provided"}
      
      # Output result
      print(json.dumps(result, indent=2))
    '';
  };
  
  # Get the appropriate loader for the model's framework
  modelLoader = if model.loadExpr != null 
                then model.loadExpr 
                else frameworkLoaders.${model.framework} or frameworkLoaders.generic;
  
  # Create a Python script to load and use the model
  runScript = ''
    #!/usr/bin/env python
    
    ${modelLoader}
  '';
  
  # Create a wrapper script
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running ${model.type} model: ${model.name} (${model.framework})"
    
    # Check if input file is provided
    if [ $# -eq 1 ]; then
      if [ ! -f "$1" ]; then
        echo "Error: Input file '$1' not found"
        exit 1
      fi
      ${pkgs.python3}/bin/python ${pkgs.writeText "run-${model.name}.py" runScript} "$1"
    else
      # Read from stdin
      ${pkgs.python3}/bin/python ${pkgs.writeText "run-${model.name}.py" runScript}
    fi
  '';
  
  # Create wrapper script derivation
  wrapperDrv = pkgs.writeScriptBin "run-${model.type}-${model.name}" wrapperScript;
  
in wrapperDrv