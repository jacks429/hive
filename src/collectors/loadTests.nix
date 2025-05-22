{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "loadTests";
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (target: config: {
        # Basic metadata
        name = config.name or target;
        description = config.description or "";
        
        # Tool configuration
        tool = config.tool or "locust";  # locust or k6
        script = config.script or null;
        
        # Load parameters
        users = config.users or 10;
        spawnRate = config.spawnRate or 1;
        duration = config.duration or "1m";
        
        # Target information
        targetService = config.targetService or "http://localhost:8000";
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Create a registry of load tests
  loadTestRegistry = l.mapAttrs (name: test: {
    inherit (test) name description tool targetService users spawnRate duration system;
  }) (walk inputs);
in
  loadTestRegistry
