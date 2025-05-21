{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "baselineResults";
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
        task = config.task or "";
        model = config.model or "";
        version = config.version or "1.0.0";
        timestamp = config.timestamp or "";
        
        # Dataset information
        dataset = config.dataset or "";
        
        # Metrics
        metrics = config.metrics or {};
        
        # Additional metadata
        metadata = config.metadata or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Create a registry of baseline results
  baselineRegistry = l.mapAttrs (name: baseline: {
    inherit (baseline) name description task model version timestamp dataset metrics metadata system;
  }) (walk inputs);
  
  # Group baselines by task
  baselinesByTask = let
    allBaselines = walk inputs;
    tasks = l.unique (map (b: b.task) (l.attrValues allBaselines));
  in
    l.genAttrs tasks (task:
      l.filter (b: b.task == task) (l.attrValues allBaselines)
    );
in
  {
    baselineResults = baselineRegistry;
    baselinesByTask = baselinesByTask;
  }