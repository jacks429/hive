{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract template definition
  template = config;
  
  # Function to validate parameters against schema
  validateParameters = params: let
    # Check required parameters
    requiredParams = l.filter (name: 
      template.parameters.${name}.required or false
    ) (l.attrNames template.parameters);
    
    missingParams = l.filter (name: 
      !(l.hasAttr name params)
    ) requiredParams;
    
    # Check parameter types
    validateType = name: value: let
      paramDef = template.parameters.${name};
      expectedType = paramDef.type or "string";
      
      typeCheckers = {
        string = l.isString;
        int = value: l.isInt value || l.isString value && builtins.match "[0-9]+" value != null;
        float = value: l.isFloat value || l.isInt value || l.isString value && builtins.match "[0-9]+([.][0-9]+)?" value != null;
        bool = value: l.isBool value || l.isString value && (value == "true" || value == "false");
        list = l.isList;
        attrs = l.isAttrs;
      };
      
      checkType = typeCheckers.${expectedType} or (v: true);
      
      # Convert value to expected type if needed
      convertedValue = 
        if expectedType == "int" && l.isString value then l.toInt value
        else if expectedType == "float" && l.isString value then l.toFloat value
        else if expectedType == "bool" && l.isString value then value == "true"
        else value;
      
    in {
      valid = checkType value;
      converted = convertedValue;
    };
    
    # Validate all parameters
    validations = l.mapAttrs validateType params;
    
    # Check for invalid parameters
    invalidParams = l.filterAttrs (name: validation: 
      !validation.valid
    ) validations;
    
    # Convert parameters to expected types
    convertedParams = l.mapAttrs (name: validation: 
      validation.converted
    ) validations;
    
  in {
    valid = missingParams == [] && invalidParams == {};
    errors = 
      (if missingParams != [] 
       then ["Missing required parameters: ${l.concatStringsSep ", " missingParams}"] 
       else []) ++
      (l.mapAttrsToList (name: _: 
        "Invalid type for parameter ${name}"
      ) invalidParams);
    convertedParams = convertedParams;
  };
  
  # Create a function to instantiate the template
  instantiateFunction = ''
    #!/usr/bin/env bash
    set -e
    
    # Parse command line arguments for parameters
    PARAMS=()
    for arg in "$@"; do
      if [[ "$arg" =~ ^--([^=]+)=(.*)$ ]]; then
        PARAM_NAME="''${BASH_REMATCH[1]}"
        PARAM_VALUE="''${BASH_REMATCH[2]}"
        PARAMS+=("--param" "$PARAM_NAME" "$PARAM_VALUE")
      elif [[ "$arg" =~ ^--([^=]+)$ ]]; then
        PARAM_NAME="''${BASH_REMATCH[1]}"
        PARAM_VALUE="true"
        PARAMS+=("--param" "$PARAM_NAME" "$PARAM_VALUE")
      else
        PARAMS+=("$arg")
      fi
    done
    
    # Create a temporary file for the instantiated pipeline
    TEMP_FILE=$(mktemp)
    
    # Generate the instantiated pipeline
    cat > $TEMP_FILE << 'EOF'
    {
      inputs,
      cell,
    }: let
      # Get the template registry
      templatesRegistry = inputs.hive.collectors.templatesRegistry (cell: target: "${cell}-${target}");
      
      # Get parameters from command line
      params = {
        ${l.concatMapStrings (name: let
          param = template.parameters.${name};
          defaultValue = if param ? default then param.default else null;
          hasDefault = param ? default;
        in
          if hasDefault
          then "${name} = builtins.getEnv \"PARAM_${name}\" or \"${toString defaultValue}\";\n"
          else "${name} = builtins.getEnv \"PARAM_${name}\";\n"
        ) (l.attrNames template.parameters)}
      };
      
      # Instantiate the template
      instantiated = templatesRegistry.instantiate${l.toUpper (l.substring 0 1 template.type) + (l.substring 1 (-1) template.type)} "${template.name}" params;
      
    in instantiated
    EOF
    
    # Print the path to the instantiated pipeline
    echo "Template instantiated at: $TEMP_FILE"
    echo "You can now copy this file to your cells directory."
  '';
  
  # Create an instantiation script derivation
  instantiateFunctionDrv = pkgs.writeScriptBin "instantiate-${template.type}-${template.name}" instantiateFunction;
  
  # Create documentation for the template
  templateDocs = ''
    # Template: ${template.name} (${template.type})
    
    ${template.description}
    
    ## Parameters
    
    ${l.concatMapStrings (paramName: let
      param = template.parameters.${paramName};
      defaultValue = if param ? default then " (default: `${toString param.default}`)" else "";
      required = if param ? required && param.required then " (required)" else "";
    in
      "- **${paramName}**${required}${defaultValue}: ${param.description or ""}\n"
    ) (l.attrNames template.parameters)}
    
    ## Usage
    
    To instantiate this template:
    
    ```bash
    # Basic usage
    nix run .#instantiate-${template.type}-${template.name} -- ${l.concatMapStrings (name: 
      let param = template.parameters.${name}; in
      if param.required or false then "--${name}=<value> " else ""
    ) (l.attrNames template.parameters)}
    
    # With all parameters
    nix run .#instantiate-${template.type}-${template.name} -- ${l.concatMapStrings (name: 
      "--${name}=<value> "
    ) (l.attrNames template.parameters)}
    ```
    
    This will generate a file that you can copy to your cells directory.
  '';
  
  # Create a documentation derivation
  templateDocsDrv = pkgs.writeTextFile {
    name = "${template.name}-template.md";
    text = templateDocs;
  };
  
in {
  # Original template data
  inherit (template) name type description parameters template;
  
  # Enhanced outputs
  validateParameters = validateParameters;
  instantiateFunction = instantiateFunctionDrv;
  documentation = templateDocsDrv;
  
  # Add metadata
  metadata = template.metadata or {};
}