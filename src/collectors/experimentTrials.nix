{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "experimentTrials";
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
        name = config.name or target;
        description = config.description or "";
        
        # Reference to the pipeline to run
        pipeline = config.pipeline or null;
        pipelineCell = config.pipelineCell or cell;
        
        # Parameter grid definition
        parameterGrid = config.parameterGrid or {};
        
        # Metrics to track
        metrics = config.metrics or [];
        
        # Output configuration
        outputPath = config.outputPath or "./results/${config.name or target}";
        
        # Trial selection strategy
        strategy = config.strategy or "grid"; # grid, random, bayesian
        maxTrials = config.maxTrials or null;
        randomSeed = config.randomSeed or 42;
        
        # Early stopping criteria
        earlyStoppingConfig = config.earlyStoppingConfig or null;
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk