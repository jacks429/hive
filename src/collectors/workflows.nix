{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "workflows";
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        
        # List of pipelines to execute
        pipelines = config.pipelines or [];
        
        # Dependencies between pipelines (DAG structure)
        dependencies = config.dependencies or {};
        
        # Optional scheduling information
        schedule = config.schedule or null;
        
        # Optional resource requirements
        resources = config.resources or {};
        
        # Optional notification configuration
        notifications = config.notifications or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk