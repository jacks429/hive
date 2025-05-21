{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "templates";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  # Walk through all template definitions in cells
  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Extract template definitions
        name = config.name or target;
        type = config.type or "pipeline"; # pipeline, step, or workflow
        description = config.description or "";
        
        # Template parameters with defaults and validation
        parameters = config.parameters or {};
        
        # Template content (steps, services, etc.)
        template = config.template or {};
        
        # Parameter validation function
        validateParameters = config.validateParameters or null;
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Function to instantiate a template with parameters
  instantiateTemplate = template: params: let
    # Validate parameters
    _ = if template.validateParameters != null 
        then template.validateParameters params
        else true;
    
    # Substitute parameters in strings
    substituteParams = str:
      l.foldl' (result: paramName:
        l.replaceStrings 
          ["{{${paramName}}}"] 
          ["${toString params.${paramName}}"] 
          result
      ) str (l.attrNames params);
    
    # Recursively substitute parameters in an attribute set
    substituteParamsRecursive = value:
      if l.isAttrs value then
        l.mapAttrs (_: substituteParamsRecursive) value
      else if l.isList value then
        l.map substituteParamsRecursive value
      else if l.isString value then
        substituteParams value
      else
        value;
    
    # Apply parameters to template
    instantiated = substituteParamsRecursive template.template;
    
  in instantiated // {
    _templateName = template.name;
    _templateParams = params;
  };
    
in {
  # Return the collected templates
  templates = walk;
  
  # Helper function for template instantiation
  instantiateTemplate = instantiateTemplate;
}