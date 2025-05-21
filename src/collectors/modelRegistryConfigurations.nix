{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "modelRegistry";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  # Walk through all model definitions in cells
  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Extract model definitions
        name = config.name or target;
        pipeline = config.pipeline or null;
        version = config.version or "latest";
        framework = config.framework or "generic";
        artifact = config.artifact or null;
        
        # Metadata
        metrics = config.metrics or {};
        lineage = config.lineage or {};
        description = config.description or "";
        
        # Framework-specific loading functions
        loadExpr = config.loadExpr or null;
        
        # Deployment configuration
        deployment = config.deployment or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Function to get model by name and version
  getModel = name: version: models:
    l.findFirst (model: model.name == name && model.version == version) 
      null 
      (l.attrValues models);
    
  # Function to get latest model by name
  getLatestModel = name: models:
    let
      matchingModels = l.filter (model: model.name == name) (l.attrValues models);
      sortedModels = l.sort (a: b: a.version > b.version) matchingModels;
    in
      if sortedModels == [] then null else l.head sortedModels;
    
  # Function to get models by pipeline
  getModelsByPipeline = pipeline: models:
    l.filter (model: model.pipeline == pipeline) (l.attrValues models);
    
  # Function to get models by framework
  getModelsByFramework = framework: models:
    l.filter (model: model.framework == framework) (l.attrValues models);
    
in {
  # Return the collected models
  models = walk;
  
  # Helper functions for model resolution
  getModel = getModel;
  getLatestModel = getLatestModel;
  getModelsByPipeline = getModelsByPipeline;
  getModelsByFramework = getModelsByFramework;
}