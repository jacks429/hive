{
  nixpkgs,
  root,
}: model: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${model.system};
  
  # Create a wrapper script to serve the model
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting model service: ${model.name} (${model.framework})"
    echo "Service will be available at http://${model.service.host or "0.0.0.0"}:${toString (model.service.port or 8000)}"
    
    # Create temporary model config
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${model.name}",
      "framework": "${model.framework}",
      "architecture": ${builtins.toJSON model.architecture},
      "params": ${builtins.toJSON model.params},
      "service": {
        "host": "${model.service.host or "0.0.0.0"}",
        "port": ${toString (model.service.port or 8000)}
      }
    }
    EOF
    
    # Run the appropriate model server based on framework
    if [ "${model.framework}" == "pytorch" ]; then
      ${pkgs.python3.withPackages (ps: with ps; [ pytorch torchvision fastapi uvicorn pydantic ])}/bin/python ${root.utils.modelServers}/pytorch_server.py \
        --config "$CONFIG_FILE" \
        ${if model.customLoadModel != null then "--custom-loader ${model.customLoadModel}" else ""} \
        ${if model.customInference != null then "--custom-inference ${model.customInference}" else ""}
    elif [ "${model.framework}" == "tensorflow" ]; then
      ${pkgs.python3.withPackages (ps: with ps; [ tensorflow fastapi uvicorn pydantic ])}/bin/python ${root.utils.modelServers}/tensorflow_server.py \
        --config "$CONFIG_FILE" \
        ${if model.customLoadModel != null then "--custom-loader ${model.customLoadModel}" else ""} \
        ${if model.customInference != null then "--custom-inference ${model.customInference}" else ""}
    else
      # For custom frameworks, use the provided custom imports and code
      ${pkgs.python3.withPackages (ps: with ps; [ fastapi uvicorn pydantic ])}/bin/python ${root.utils.modelServers}/generic_server.py \
        --config "$CONFIG_FILE" \
        ${if model.customImports != null then "--custom-imports ${model.customImports}" else ""} \
        ${if model.customLoadModel != null then "--custom-loader ${model.customLoadModel}" else ""} \
        ${if model.customInference != null then "--custom-inference ${model.customInference}" else ""}
    fi
    
    # Clean up
    rm "$CONFIG_FILE"
  '';
  
  # Create wrapper script derivation
  wrapperDrv = pkgs.writeScriptBin "serve-model-${model.name}" wrapperScript;
  
in wrapperDrv
