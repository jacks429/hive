{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "evaluation-workflows";
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
        
        # Data loading stage
        dataLoader = config.dataLoader or "";
        dataLoaderParams = config.dataLoaderParams or {};
        
        # Model/pipeline stage
        model = config.model or "";
        modelParams = config.modelParams or {};
        modelOutput = config.modelOutput or "./model-output.json";
        
        # Reference data for evaluation
        referenceData = config.referenceData or "./reference-data.json";
        
        # Evaluation metrics
        metrics = config.metrics or [];
        metricParams = config.metricParams or {};
        
        # System information
        system = config.system or system;
      }))
      (l.mapAttrs (_: root.transformers.evaluationWorkflows))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk