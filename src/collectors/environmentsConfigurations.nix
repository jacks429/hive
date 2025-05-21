{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "environments";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  # Walk through all environment definitions in cells
  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Extract environment definitions
        name = config.name or target;
        description = config.description or "";
        
        # Configuration overlays
        overlays = config.overlays or {};
        
        # Resource quotas
        resources = config.resources or {};
        
        # Service URLs and endpoints
        services = config.services or {};
        
        # Secrets management
        secrets = config.secrets or {};
        
        # Environment variables
        variables = config.variables or {};
        
        # Optional metadata
        metadata = config.metadata or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Function to get environment by name
  getEnvironment = envName: environments:
    l.findFirst (env: env.name == envName) null (l.attrValues environments);
    
  # Function to merge environment overlays into a configuration
  mergeEnvironmentOverlays = envName: config: environments:
    let
      env = getEnvironment envName environments;
    in
      if env == null
      then config
      else l.recursiveUpdate config (env.overlays or {});
    
  # Function to get environment variables
  getEnvironmentVariables = envName: environments:
    let
      env = getEnvironment envName environments;
    in
      if env == null
      then {}
      else env.variables or {};
    
in {
  # Return the collected environments
  environments = walk;
  
  # Helper functions for environment resolution
  getEnvironment = getEnvironment;
  mergeEnvironmentOverlays = mergeEnvironmentOverlays;
  getEnvironmentVariables = getEnvironmentVariables;
}