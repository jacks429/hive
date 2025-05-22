{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "parameters";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  # Walk through all parameter definitions in cells
  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (target: config: {
        # Extract parameter definitions
        name = config.name or target;
        description = config.description or "";
        type = config.type or "string";
        default = config.default;
        
        # Optional constraints
        constraints = config.constraints or {};
        
        # Optional metadata
        metadata = config.metadata or {};
        
        # Parameter group (usually pipeline name)
        group = config.group or null;
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Function to resolve parameter value with overrides
  resolveParameter = paramName: overrides: defaultValue:
    if l.hasAttr paramName overrides
    then overrides.${paramName}
    else defaultValue;
    
  # Function to resolve all parameters for a group with overrides
  resolveParametersForGroup = group: overrides: parameters:
    let
      groupParams = l.filterAttrs (_: param: param.group == group) parameters;
    in
      l.mapAttrs (name: param:
        resolveParameter name overrides param.default
      ) groupParams;
    
in {
  # Return the collected parameters
  parameters = walk;
  
  # Helper functions for parameter resolution
  resolve = resolveParameter;
  resolveGroup = resolveParametersForGroup;
}
