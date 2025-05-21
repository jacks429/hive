{ inputs, nixpkgs, root, kind, cliPrefix ? "run", servicePrefix ? "serve" }:
config: let
  l = nixpkgs.lib // builtins;

  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};

  # Create a wrapper script to run the model
  runnerScript = ''
    #!/usr/bin/env bash
    set -e

    echo "Running ${kind}: ${config.meta.name}"

    # Parse arguments
    INPUT_FILE=""
    OUTPUT_FILE=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --input)
          INPUT_FILE="$2"
          shift 2
          ;;
        --output)
          OUTPUT_FILE="$2"
          shift 2
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    # Handle stdin/stdout if no files specified
    if [ -z "$INPUT_FILE" ]; then
      INPUT_FILE=$(mktemp)
      cat > "$INPUT_FILE"
      REMOVE_INPUT=1
    fi

    if [ -z "$OUTPUT_FILE" ]; then
      OUTPUT_FILE=$(mktemp)
      REMOVE_OUTPUT=1
    fi

    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "model_uri": "${config.model-uri}",
      "framework": "${config.framework}",
      "params": ${builtins.toJSON config.params}
    }
    EOF

    # Run the model based on framework
    ${if config.framework == "huggingface" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        transformers torch numpy
      ])}/bin/python ${root.utils.modelRunner}/huggingface_runner.py \
        --model-uri "${config.model-uri}" \
        --task "${kind}" \
        --input "$INPUT_FILE" \
        --output "$OUTPUT_FILE" \
        --config "$CONFIG_FILE"
    '' else if config.framework == "tensorflow" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        tensorflow numpy
      ])}/bin/python ${root.utils.modelRunner}/tensorflow_runner.py \
        --model-uri "${config.model-uri}" \
        --task "${kind}" \
        --input "$INPUT_FILE" \
        --output "$OUTPUT_FILE" \
        --config "$CONFIG_FILE"
    '' else if config.framework == "pytorch" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        torch numpy
      ])}/bin/python ${root.utils.modelRunner}/pytorch_runner.py \
        --model-uri "${config.model-uri}" \
        --task "${kind}" \
        --input "$INPUT_FILE" \
        --output "$OUTPUT_FILE" \
        --config "$CONFIG_FILE"
    '' else if config.framework == "onnx" then ''
      ${pkgs.python3.withPackages (ps: with ps; [
        onnx onnxruntime numpy
      ])}/bin/python ${root.utils.modelRunner}/onnx_runner.py \
        --model-uri "${config.model-uri}" \
        --task "${kind}" \
        --input "$INPUT_FILE" \
        --output "$OUTPUT_FILE" \
        --config "$CONFIG_FILE"
    '' else ''
      echo "Unsupported framework: ${config.framework}"
      exit 1
    ''}

    # Output results
    if [ -n "$REMOVE_OUTPUT" ]; then
      cat "$OUTPUT_FILE"
      rm "$OUTPUT_FILE"
    fi

    # Clean up
    if [ -n "$REMOVE_INPUT" ]; then
      rm "$INPUT_FILE"
    fi

    rm "$CONFIG_FILE"
  '';

  # Create service script if enabled
  serviceScript = if config.service.enable then ''
    #!/usr/bin/env bash
    set -e

    echo "Starting ${kind} service: ${config.meta.name}"
    echo "Listening on ${config.service.host}:${toString config.service.port}"

    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "model_uri": "${config.model-uri}",
      "framework": "${config.framework}",
      "params": ${builtins.toJSON config.params},
      "service": {
        "host": "${config.service.host}",
        "port": ${toString config.service.port}
      }
    }
    EOF

    # Run the service based on framework
    ${pkgs.python3.withPackages (ps: with ps; [
      fastapi uvicorn transformers torch tensorflow onnx onnxruntime numpy
    ])}/bin/python ${root.utils.modelService}/service.py \
      --model-uri "${config.model-uri}" \
      --framework "${config.framework}" \
      --task "${kind}" \
      --host "${config.service.host}" \
      --port "${toString config.service.port}" \
      --config "$CONFIG_FILE"

    # Clean up
    rm "$CONFIG_FILE"
  '' else null;

  # Create documentation
  documentation = ''
    # ${l.toUpper kind}: ${config.meta.name}

    ${config.meta.description}

    ## Framework

    This model uses the **${config.framework}** framework.

    ## Parameters

    ```json
    ${builtins.toJSON config.params}
    ```

    ## Usage

    ### Process input

    ```bash
    # Process text from stdin
    echo "Text to process" | nix run .#${cliPrefix}-${kind}-${config.meta.name}

    # Process text from file
    nix run .#${cliPrefix}-${kind}-${config.meta.name} -- --input input.txt --output result.txt
    ```

    ${if config.service.enable then ''
    ### Start as a service

    ```bash
    nix run .#${servicePrefix}-${kind}-${config.meta.name}

    # Then use the API
    curl -X POST http://${config.service.host}:${toString config.service.port}/process \
      -H "Content-Type: application/json" \
      -d '{"text": "Text to process"}'
    ```
    '' else ""}
  '';

  # Create derivations
  runnerDrv = pkgs.writeScriptBin "${cliPrefix}-${kind}-${config.meta.name}" runnerScript;
  serviceDrv = if config.service.enable
    then pkgs.writeScriptBin "${servicePrefix}-${kind}-${config.meta.name}" serviceScript
    else null;
  docsDrv = pkgs.writeTextFile {
    name = "${kind}-${config.meta.name}-docs";
    text = documentation;
    destination = "/share/doc/${kind}-${config.meta.name}.md";
  };

  # Create a derivation that bundles everything together
  packageDrv = pkgs.symlinkJoin {
    name = "${kind}-${config.meta.name}";
    paths = if config.service.enable
      then [ runnerDrv serviceDrv docsDrv ]
      else [ runnerDrv docsDrv ];
  };

in {
  # Original model configuration
  inherit (config) framework params;
  model-uri = config.model-uri or config.modelUri;
  inherit (config) meta service system;

  # Derivations
  runner = runnerDrv;
  service = serviceDrv;
  docs = docsDrv;
  package = packageDrv;
}