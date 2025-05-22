# Provide default values for required inputs
{
  inputs ? {},
  nixpkgs,
  root,
  modelType ? "generic",  # Add default value
  cell ? "default",       # Add default value
  config ? {},           # Add config parameter with default empty attrset
}: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  # Use a default system if config.system is not available
  pkgs = nixpkgs.legacyPackages.${config.system or "x86_64-linux"};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Apply defaults to configuration with tracing
  model = let
    debugConfig = l.trace "Processing ${modelType}: ${config.meta.name or "unnamed"} (framework: ${config.framework or "unknown"})" config;
  in transformers.withDefaults debugConfig {
    service = { enable = false; host = "0.0.0.0"; port = 8000; };
    params = {};
  };
  
  # Create a wrapper script to run the model using the transformers library
  runnerScript = transformers.withArgs {
    name = "${cliPrefix}-${modelType}-${model.meta.name}";
    description = "Run ${modelType} model: ${model.meta.name}";
    args = [];
    flags = [
      { name = "input"; description = "Input file (default: stdin)"; type = "string"; }
      { name = "output"; description = "Output file (default: stdout)"; type = "string"; }
      { name = "debug"; description = "Enable debug output"; type = "boolean"; }
    ];
  } ''
    ${l.optionalString true "set -e"}
    
    # Enable debug mode if requested
    if [ -n "$debug" ]; then
      set -x
      echo "DEBUG: Running in debug mode"
      echo "DEBUG: Model type: ${modelType}"
      echo "DEBUG: Model name: ${model.meta.name}"
      echo "DEBUG: Framework: ${model.framework}"
      echo "DEBUG: Model URI: ${model.model-uri}"
    fi
    
    echo "Running ${modelType}: ${model.meta.name}"
    
    # Handle stdin/stdout if no files specified
    if [ -z "$input" ]; then
      input=$(mktemp)
      cat > "$input"
      REMOVE_INPUT=1
      [ -n "$debug" ] && echo "DEBUG: Reading from stdin, temp file: $input"
    else
      [ -n "$debug" ] && echo "DEBUG: Reading from file: $input"
    fi
    
    if [ -z "$output" ]; then
      output=$(mktemp)
      REMOVE_OUTPUT=1
      [ -n "$debug" ] && echo "DEBUG: Writing to stdout, temp file: $output"
    else
      [ -n "$debug" ] && echo "DEBUG: Writing to file: $output"
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
    [ -n "$debug" ] && echo "DEBUG: Config file created at: $CONFIG_FILE"
    [ -n "$debug" ] && echo "DEBUG: Config contents:" && cat "$CONFIG_FILE"
    
    # Run the model based on framework
    ${if model.framework == "huggingface" then ''
      [ -n "$debug" ] && echo "DEBUG: Using HuggingFace framework"
      ${pkgs.python3.withPackages (ps: with ps; [
        transformers torch numpy
      ])}/bin/python ${root.utils.modelRunner}/huggingface_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${modelType}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE" \
        ${l.optionalString true "--debug $debug"}
    '' else if model.framework == "tensorflow" then ''
      [ -n "$debug" ] && echo "DEBUG: Using TensorFlow framework"
      ${pkgs.python3.withPackages (ps: with ps; [
        tensorflow numpy
      ])}/bin/python ${root.utils.modelRunner}/tensorflow_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${modelType}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE" \
        ${l.optionalString true "--debug $debug"}
    '' else if model.framework == "pytorch" then ''
      [ -n "$debug" ] && echo "DEBUG: Using PyTorch framework"
      ${pkgs.python3.withPackages (ps: with ps; [
        torch numpy
      ])}/bin/python ${root.utils.modelRunner}/pytorch_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${modelType}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE" \
        ${l.optionalString true "--debug $debug"}
    '' else if model.framework == "onnx" then ''
      [ -n "$debug" ] && echo "DEBUG: Using ONNX framework"
      ${pkgs.python3.withPackages (ps: with ps; [
        onnx onnxruntime numpy
      ])}/bin/python ${root.utils.modelRunner}/onnx_runner.py \
        --model-uri "${model.model-uri}" \
        --task "${modelType}" \
        --input "$input" \
        --output "$output" \
        --config "$CONFIG_FILE" \
        ${l.optionalString true "--debug $debug"}
    '' else ''
      echo "Unsupported framework: ${model.framework}"
      exit 1
    ''}
    
    # Output results
    if [ -n "$REMOVE_OUTPUT" ]; then
      [ -n "$debug" ] && echo "DEBUG: Outputting results to stdout"
      cat "$output"
      rm "$output"
    fi
    
    # Clean up
    if [ -n "$REMOVE_INPUT" ]; then
      [ -n "$debug" ] && echo "DEBUG: Removing temporary input file"
      rm "$input"
    fi
    
    [ -n "$debug" ] && echo "DEBUG: Removing temporary config file"
    rm "$CONFIG_FILE"
  '';
  
  # Create service script if enabled using the transformers library
  serviceScript = if model.service.enable then
    transformers.withArgs {
      name = "${servicePrefix}-${modelType}-${model.meta.name}";
      description = "Start ${modelType} service: ${model.meta.name}";
      flags = [
        { name = "debug"; description = "Enable debug output"; type = "boolean"; }
      ];
    } ''
      ${l.optionalString true "set -e"}
      
      # Enable debug mode if requested
      if [ -n "$debug" ]; then
        set -x
        echo "DEBUG: Running service in debug mode"
        echo "DEBUG: Model type: ${modelType}"
        echo "DEBUG: Model name: ${model.meta.name}"
        echo "DEBUG: Framework: ${model.framework}"
        echo "DEBUG: Model URI: ${model.model-uri}"
        echo "DEBUG: Service host: ${model.service.host}"
        echo "DEBUG: Service port: ${toString model.service.port}"
      fi
      
      echo "Starting ${modelType} service: ${model.meta.name}"
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
      [ -n "$debug" ] && echo "DEBUG: Config file created at: $CONFIG_FILE"
      [ -n "$debug" ] && echo "DEBUG: Config contents:" && cat "$CONFIG_FILE"
      
      # Run the service based on framework
      ${pkgs.python3.withPackages (ps: with ps; [
        fastapi uvicorn transformers torch tensorflow onnx onnxruntime numpy
      ])}/bin/python ${root.utils.modelService}/service.py \
        --model-uri "${model.model-uri}" \
        --framework "${model.framework}" \
        --task "${modelType}" \
        --host "${model.service.host}" \
        --port "${toString model.service.port}" \
        --config "$CONFIG_FILE" \
        ${l.optionalString true "--debug $debug"}
      
      # Clean up
      [ -n "$debug" ] && echo "DEBUG: Removing temporary config file"
      rm "$CONFIG_FILE"
    ''
  else null;
  
  # Generate documentation using the transformers library
  modelDocs = transformers.generateDocs {
    name = "${l.toUpper modelType}: ${model.meta.name}";
    description = model.meta.description;
    usage = ''
      ```bash
      # Process text from stdin
      echo "Text to process" | ${cliPrefix}-${modelType}-${model.meta.name}
      
      # Process text from file
      ${cliPrefix}-${modelType}-${model.meta.name} --input input.txt --output result.txt
      
      # Run with debug output
      ${cliPrefix}-${modelType}-${model.meta.name} --debug
      ```
      
      ${if model.service.enable then ''
      To start as a service:
      
      ```bash
      ${servicePrefix}-${modelType}-${model.meta.name}
      
      # Start service with debug output
      ${servicePrefix}-${modelType}-${model.meta.name} --debug
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
      echo "Example input" | ${cliPrefix}-${modelType}-${model.meta.name}
      
      # Example 2: Process text from file
      ${cliPrefix}-${modelType}-${model.meta.name} --input input.txt --output result.txt
      
      # Example 3: Debug mode
      ${cliPrefix}-${modelType}-${model.meta.name} --debug
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
      debug = {
        description = "Enable debug output";
        type = "boolean";
        value = false;
      };
    };
  };
  
  # Create derivations with debug tracing
  runnerDrv = let
    debugName = "${cliPrefix}-${modelType}-${model.meta.name}";
    _ = l.trace "Creating runner derivation: ${debugName}" null;
  in transformers.mkScript {
    name = debugName;
    description = "Run ${modelType} model: ${model.meta.name}";
    script = runnerScript;
  };
  
  serviceDrv = if model.service.enable then
    let
      debugName = "${servicePrefix}-${modelType}-${model.meta.name}";
      _ = l.trace "Creating service derivation: ${debugName}" null;
    in transformers.mkScript {
      name = debugName;
      description = "Start ${modelType} service: ${model.meta.name}";
      script = serviceScript;
    }
  else null;
  
  docsDrv = transformers.mkDocs {
    name = "${modelType}-${model.meta.name}";
    content = modelDocs;
  };
  
  # Create a package derivation using the transformers library
  packageDrv = transformers.mkPackage {
    name = "${modelType}-${model.meta.name}";
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
  serviceDrv = serviceDrv;
  docs = docsDrv;
  package = packageDrv;
}

