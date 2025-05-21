{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract parameter definition
  parameter = config;
  
  # Create a JSON schema for this parameter
  jsonSchema = {
    type = parameter.type;
    description = parameter.description;
    default = parameter.default;
  } // (
    if parameter.type == "string" && parameter.constraints ? pattern then {
      pattern = parameter.constraints.pattern;
    } else {}
  ) // (
    if parameter.type == "enum" then {
      enum = parameter.constraints.values;
    } else {}
  ) // (
    if (parameter.type == "int" || parameter.type == "float") then
      l.filterAttrs (n: _: n == "minimum" || n == "maximum") {
        minimum = parameter.constraints.min or null;
        maximum = parameter.constraints.max or null;
      }
    else {}
  );
  
  # Create a validation script for this parameter
  validationScript = ''
    #!/usr/bin/env bash
    set -e
    
    VALUE="$1"
    
    # Validate type
    ${if parameter.type == "int" then ''
      if ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
        echo "Error: Parameter must be an integer"
        exit 1
      fi
    '' else if parameter.type == "float" then ''
      if ! [[ "$VALUE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: Parameter must be a number"
        exit 1
      fi
    '' else if parameter.type == "bool" then ''
      if ! [[ "$VALUE" == "true" || "$VALUE" == "false" ]]; then
        echo "Error: Parameter must be 'true' or 'false'"
        exit 1
      fi
    '' else if parameter.type == "enum" then ''
      VALID_VALUES=(${l.concatStringsSep " " (map (v: "\"${v}\"") parameter.constraints.values)})
      VALID=0
      for v in "''${VALID_VALUES[@]}"; do
        if [[ "$VALUE" == "$v" ]]; then
          VALID=1
          break
        fi
      done
      if [[ $VALID -eq 0 ]]; then
        echo "Error: Parameter must be one of: ${l.concatStringsSep ", " parameter.constraints.values}"
        exit 1
      fi
    '' else ""}
    
    # Validate range
    ${if (parameter.type == "int" || parameter.type == "float") && (parameter.constraints ? min) then ''
      if (( $(echo "$VALUE < ${toString parameter.constraints.min}" | bc -l) )); then
        echo "Error: Parameter must be >= ${toString parameter.constraints.min}"
        exit 1
      fi
    '' else ""}
    ${if (parameter.type == "int" || parameter.type == "float") && (parameter.constraints ? max) then ''
      if (( $(echo "$VALUE > ${toString parameter.constraints.max}" | bc -l) )); then
        echo "Error: Parameter must be <= ${toString parameter.constraints.max}"
        exit 1
      fi
    '' else ""}
    
    # Validate pattern
    ${if parameter.type == "string" && parameter.constraints ? pattern then ''
      if ! [[ "$VALUE" =~ ${parameter.constraints.pattern} ]]; then
        echo "Error: Parameter must match pattern '${parameter.constraints.pattern}'"
        exit 1
      fi
    '' else ""}
    
    echo "Parameter validation successful"
    exit 0
  '';
  
  # Create a validation script derivation
  validationDrv = pkgs.writeScriptBin "validate-${parameter.name}" validationScript;
  
  # Create a JSON schema derivation
  schemaDrv = pkgs.writeTextFile {
    name = "${parameter.name}-schema.json";
    text = l.toJSON jsonSchema;
  };
  
in {
  # Original parameter data
  inherit (parameter) name description type default constraints group system;
  
  # Enhanced outputs
  jsonSchema = jsonSchema;
  validator = validationDrv;
  schema = schemaDrv;
  
  # Add metadata
  metadata = parameter.metadata or {};
}