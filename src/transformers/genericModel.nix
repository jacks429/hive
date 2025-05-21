{ inputs, nixpkgs, root, kind, cliPrefix ? "run", servicePrefix ? "serve" }:
config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Apply defaults to configuration
  model = transformers.withDefaults config {
    service = { enable = false; host = "0.0.0.0"; port = 8000; };
    params = {};
  };
  
  # Create a wrapper script to run the model using the transformers library
  runnerScript = transformers.withArgs {
    name = "${cliPrefix}-${kind}-${model.meta.name}";
    description = "Run ${kind} model: ${model.meta.name}";
    args = [];
    flags = [
      { name = "input"; description = "Input file (default: stdin)"; type = "string"; }
      { name = "output"; description = "Output file (default: stdout)"; type = "string"; }
    ];
  } ''
    echo "Running ${kind}: ${model.meta.name}"
    
    # Handle stdin/stdout if no files specified
    if [ -z "$input" ]; then
      input=$(mktemp)
      cat > "$input"
      REMOVE_INPUT=1
    fi
    
    if [ -z "$output" ]; then
      output=$(mktemp)
      REMOVE_OUTPUT=1
    fi
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "model_uri": "${model.model-uri}",
      "framework": "${model.framework}",
      "params": ${transformers.toJSON model.params}
    }
    EOF
    
    # Run the model based on framework
    ${if model.framework == "huggingface" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        transformers torch numpy
      ])}/bin/python ${root.utils.modelRunner}/huggingface_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${kind}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE"
    '' else if model.framework == "tensorflow" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        tensorflow numpy
      ])}/bin/python ${root.utils.modelRunner}/tensorflow_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${kind}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE"
    '' else if model.framework == "pytorch" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        torch numpy
      ])}/bin/python ${root.utils.modelRunner}/pytorch_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${kind}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE"
    '' else if model.framework == "onnx" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        onnx onnxruntime numpy
      ])}/bin/python ${root.utils.modelRunner}/onnx_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${kind}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE"
    '' else ''
      echo "Unsupported framework: ${model.framework}"
      exit 1
    ''}
    
    # Output results
    if [ -n "$REMOVE_OUTPUT" ]; then
      cat "$output"
      rm "$output"
    fi
    
    # Clean up
    if [ -n "$REMOVE_INPUT" ]; then
      rm "$input"
    fi
    
    rm "$CONFIG_FILE"
  '';
  
  # Create service script if enabled using the transformers library
  serviceScript = if model.service.enable then
    transformers.withArgs {
      name = "${servicePrefix}-${kind}-${model.meta.name}";
      description = "Start ${kind} service: ${model.meta.name}";
    } ''
      echo "Starting ${kind} service: ${model.meta.name}"
      echo "Listening on ${model.service.host}:${toString model.service.port}"
      
      # Create temporary config file
      CONFIG_FILE=$(mktemp)
      cat > "$CONFIG_FILE" << EOF
      {
        "model_uri": "${model.model-uri}",
        "framework": "${model.framework}",
        "params": ${transformers.toJSON model.params},
        "service": {
          "host": "${model.service.host}",
          "port": ${toString model.service.port}
        }
      }
      EOF
      
      # Run the service based on framework
      ${pkgs.python3.withPackages (ps: with ps; [
        fastapi uvicorn transformers torch tensorflow onnx onnxruntime numpy
      ])}/bin/python ${root.utils.modelService}/service.py \
        --model-uri "${model.model-uri}" \
        --framework "${model.framework}" \
        --task "${kind}" \
        --host "${model.service.host}" \
        --port "${toString model.service.port}" \
        --config "$CONFIG_FILE"
      
      # Clean up
      rm "$CONFIG_FILE"
    ''
  else null;
  
  # Generate documentation using the transformers library
  modelDocs = transformers.generateDocs {
    name = "${l.toUpper kind}: ${model.meta.name}";
    description = model.meta.description;
    usage = ''
      ```bash
      # Process text from stdin
      echo "Text to process" | ${cliPrefix}-${kind}-${model.meta.name}
      
      # Process text from file
      ${cliPrefix}-${kind}-${model.meta.name} --input input.txt --output result.txt
      ```
      
      ${if model.service.enable then ''
      To start as a service:
      
      ```bash
      ${servicePrefix}-${kind}-${model.meta.name}
      ```
      
      Then use the API:
      
      ```bash
      curl -X POST http://${model.service.host}:${toString model.service.port}/process \
        -H "Content-Type: application/json" \
        -d '{"text": "Text to process"}'
      ```
      '' else ""}
    '';
    examples = ''
      ```bash
      # Example 1: Process text from stdin
      echo "Example input" | ${cliPrefix}-${kind}-${model.meta.name}
      
      # Example 2: Process text from file
      ${cliPrefix}-${kind}-${model.meta.name} --input input.txt --output result.txt
      ```
    '';
    params = {
      framework = {
        description = "Framework used by the model";
        type = "string";
        value = model.framework;
      };
      model-uri = {
        description = "URI of the model to use";
        type = "string";
        value = model.model-uri;
      };
      params = {
        description = "Model parameters";
        type = "attrset";
        value = model.params;
      };
    };
  };
  
  # Create derivations using the transformers library
  runnerDrv = transformers.mkScript {
    name = "${cliPrefix}-${kind}-${model.meta.name}";
    description = "Run ${kind} model: ${model.meta.name}";
    script = runnerScript;
  };
  
  serviceDrv = if model.service.enable then
    transformers.mkScript {
      name = "${servicePrefix}-${kind}-${model.meta.name}";
      description = "Start ${kind} service: ${model.meta.name}";
      script = serviceScript;
    }
  else null;
  
  docsDrv = transformers.mkDocs {
    name = "${kind}-${model.meta.name}";
    content = modelDocs;
  };
  
  # Create a package derivation using the transformers library
  packageDrv = transformers.mkPackage {
    name = "${kind}-${model.meta.name}";
    paths = if model.service.enable
      then [ runnerDrv serviceDrv docsDrv ]
      else [ runnerDrv docsDrv ];
  };
  
in {
  # Original model configuration
  inherit (model) framework params;
  model-uri = model.model-uri;
  inherit (model) meta service system;
  
  # Derivations
  runner = runnerDrv;
  service = serviceDrv;
  docs = docsDrv;
  package = packageDrv;
}
