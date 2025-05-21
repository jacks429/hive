{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all model registry configurations
  models = root.collectors.modelRegistryConfigurations renamer;
  
  # Create a registry of model definitions, keyed by name-version
  modelRegistry = l.listToAttrs (
    l.map (model: 
      l.nameValuePair "${model.name}-${model.version}" model
    ) (l.attrValues models)
  );
  
  # Function to get a model by name and version
  getModel = name: version:
    let key = "${name}-${version}";
    in if l.hasAttr key modelRegistry
       then modelRegistry.${key}
       else throw "Model not found: ${name} version ${version}";
    
  # Function to get the latest version of a model by name
  getLatestModel = name:
    let
      matchingModels = l.filter (model: l.hasPrefix "${name}-" (l.fst model)) (l.attrsToList modelRegistry);
      sortedModels = l.sort (a: b: (l.snd a).version > (l.snd b).version) matchingModels;
    in
      if sortedModels == [] 
      then throw "No models found with name: ${name}"
      else l.snd (l.head sortedModels);
    
  # Function to get all models for a specific pipeline
  getModelsByPipeline = pipeline:
    l.filter (model: model.pipeline == pipeline) (l.attrValues modelRegistry);
    
  # Function to get all models for a specific framework
  getModelsByFramework = framework:
    l.filter (model: model.framework == framework) (l.attrValues modelRegistry);
    
  # Function to get all model names
  getModelNames = l.unique (
    l.map (key: l.head (l.splitString "-" key)) (l.attrNames modelRegistry)
  );
    
  # Function to get all versions for a specific model
  getModelVersions = name:
    let
      matchingModels = l.filter (key: l.hasPrefix "${name}-" key) (l.attrNames modelRegistry);
      versions = l.map (key: l.last (l.splitString "-" key)) matchingModels;
    in
      l.sort (a: b: a > b) versions;
    
  # Generate documentation for all models
  allModelsDocs = let
    modelsList = l.mapAttrsToList (key: model: ''
      ## Model: ${model.name} (version ${model.version})
      
      ${model.description}
      
      - **Framework:** ${model.framework}
      - **Pipeline:** ${model.pipeline or "N/A"}
      - **Artifact:** ${model.artifact or "N/A"}
      
      ### Metrics
      
      ${l.concatMapStrings (key: "- ${key}: ${l.toJSON model.metrics.${key}}\n") 
        (l.attrNames (model.metrics or {}))}
      
      ### Lineage
      
      ${l.concatMapStrings (key: "- ${key}: ${l.toJSON model.lineage.${key}}\n") 
        (l.attrNames (model.lineage or {}))}
      
      ---
    '') modelRegistry;
  in ''
    # Model Registry
    
    This document contains information about all registered models.
    
    ${l.concatStringsSep "\n" modelsList}
  '';
  
  # Generate a comparison table for models with the same name but different versions
  modelComparisonDocs = let
    modelNames = getModelNames;
    modelComparisons = l.map (name: let
      versions = getModelVersions name;
      models = l.map (version: getModel name version) versions;
      
      # Get all possible metric keys across all versions
      allMetricKeys = l.unique (l.concatMap (model: 
        l.attrNames (model.metrics or {})
      ) models);
      
      # Generate metric comparison rows
      metricRows = l.concatMapStrings (key: ''
        | ${key} | ${l.concatMapStrings (model: 
          "${l.toJSON (l.attrByPath ["metrics" key] "N/A" model)} | "
        ) models}
      '') allMetricKeys;
      
    in ''
      ## ${name}
      
      | Version | ${l.concatMapStrings (model: "${model.version} | ") models}
      |---------|${l.concatMapStrings (_: "---------|") models}
      | Framework | ${l.concatMapStrings (model: "${model.framework} | ") models}
      | Pipeline | ${l.concatMapStrings (model: "${model.pipeline or "N/A"} | ") models}
      ${metricRows}
      
      ---
    '') modelNames;
  in ''
    # Model Comparison
    
    This document compares different versions of the same model.
    
    ${l.concatStringsSep "\n" modelComparisons}
  '';
  
in {
  registry = modelRegistry;
  documentation = allModelsDocs;
  comparisonDocs = modelComparisonDocs;
  
  # Helper functions
  getModel = getModel;
  getLatestModel = getLatestModel;
  getModelsByPipeline = getModelsByPipeline;
  getModelsByFramework = getModelsByFramework;
  getModelNames = getModelNames;
  getModelVersions = getModelVersions;
}