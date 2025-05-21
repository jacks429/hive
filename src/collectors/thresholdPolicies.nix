{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "thresholdPolicies";
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
        
        # Thresholds
        thresholds = config.thresholds or [];
        
        # Slice-specific thresholds
        slices = config.slices or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Create a registry of threshold policies
  thresholdRegistry = l.mapAttrs (name: policy: {
    inherit (policy) name description task thresholds slices system;
  }) (walk inputs);
  
  # Group policies by task
  policiesByTask = let
    allPolicies = walk inputs;
    tasks = l.unique (map (p: p.task) (l.attrValues allPolicies));
  in
    l.genAttrs tasks (task:
      l.filter (p: p.task == task) (l.attrValues allPolicies)
    );
in
  {
    thresholdPolicies = thresholdRegistry;
    policiesByTask = policiesByTask;
  }