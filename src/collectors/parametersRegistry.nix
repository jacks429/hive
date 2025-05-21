{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all parameter configurations
  parameters = root.collectors.parametersConfigurations renamer;
  
  # Create a registry of parameter definitions, keyed by name
  parametersRegistry = parameters;
  
  # Group parameters by group (pipeline)
  parametersByGroup = l.groupBy 
    (param: param.group or "global") 
    (l.attrValues parametersRegistry);
  
  # Function to get parameters for a specific group
  getParametersForGroup = group:
    parametersByGroup.${group} or [];
    
  # Function to get a specific parameter
  getParameter = name:
    if l.hasAttr name parametersRegistry
    then parametersRegistry.${name}
    else null;
    
  # Function to resolve parameter value with overrides
  resolveParameter = name: overrides:
    let param = getParameter name;
    in
      if param == null
      then throw "Parameter not found: ${name}"
      else if l.hasAttr name overrides
      then overrides.${name}
      else param.default;
    
  # Function to resolve all parameters for a group with overrides
  resolveParametersForGroup = group: overrides:
    let
      groupParams = getParametersForGroup group;
      paramNames = map (p: p.name) groupParams;
    in
      l.listToAttrs (map (name: {
        inherit name;
        value = resolveParameter name overrides;
      }) paramNames);
    
  # Function to validate parameter value against constraints
  validateParameter = name: value:
    let
      param = getParameter name;
      
      # Check type constraint
      typeValid = 
        if param.type == "string" then l.isString value
        else if param.type == "int" then l.isInt value
        else if param.type == "float" then l.isFloat value
        else if param.type == "bool" then l.isBool value
        else if param.type == "path" then l.isPath value
        else if param.type == "enum" then l.elem value param.constraints.values
        else true;
        
      # Check range constraint for numeric types
      rangeValid =
        if (param.type == "int" || param.type == "float") && 
           (param.constraints ? min || param.constraints ? max)
        then
          (if param.constraints ? min then value >= param.constraints.min else true) &&
          (if param.constraints ? max then value <= param.constraints.max else true)
        else true;
        
      # Check pattern constraint for string type
      patternValid =
        if param.type == "string" && param.constraints ? pattern
        then l.match param.constraints.pattern value != null
        else true;
    in
      typeValid && rangeValid && patternValid;
    
  # Function to validate all parameters for a group with overrides
  validateParametersForGroup = group: overrides:
    let
      groupParams = getParametersForGroup group;
      paramNames = map (p: p.name) groupParams;
      
      validations = map (name: {
        inherit name;
        value = validateParameter name (resolveParameter name overrides);
      }) paramNames;
      
      invalidParams = l.filter (v: !v.value) validations;
    in
      if invalidParams == []
      then true
      else throw "Invalid parameters: ${l.concatStringsSep ", " (map (p: p.name) invalidParams)}";
    
  # Generate documentation for all parameters
  allParametersDocs = let
    parametersList = l.mapAttrsToList (name: param: ''
      ## Parameter: ${name}
      
      **Group:** ${param.group or "global"}
      **Type:** ${param.type}
      **Default:** \`${l.toJSON param.default}\`
      
      ${param.description}
      
      ${l.optionalString (param.constraints != {}) ''
      ### Constraints
      ${l.concatMapStrings (key: "- ${key}: ${l.toJSON param.constraints.${key}}\n") 
        (l.attrNames param.constraints)}
      ''}
      
      ---
    '') parametersRegistry;
  in ''
    # Parameters Registry
    
    This document contains information about all available parameters.
    
    ${l.concatStringsSep "\n" parametersList}
  '';
  
in {
  registry = parametersRegistry;
  byGroup = parametersByGroup;
  documentation = allParametersDocs;
  
  # Helper functions
  getParameter = getParameter;
  getParametersForGroup = getParametersForGroup;
  resolveParameter = resolveParameter;
  resolveParametersForGroup = resolveParametersForGroup;
  validateParameter = validateParameter;
  validateParametersForGroup = validateParametersForGroup;
}