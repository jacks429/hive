{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all datasets
  datasets = root.collectors.datasets renamer;
  
  # Create a registry of dataset definitions, keyed by name
  datasetsRegistry = l.mapAttrs (name: dataset: {
    inherit (dataset) name system type description path;
    metadata = dataset.metadata or {};
  }) datasets;
  
  # Generate combined documentation for all datasets
  allDatasetsDocs = let
    datasetsList = l.mapAttrsToList (name: dataset: ''
      ## Dataset: ${name}
      
      ${dataset.description}
      
      **Type:** ${dataset.type}
      **System:** ${dataset.system}
      **Path:** \`${dataset.path}\`
      
      ${l.optionalString (dataset ? metadata) ''
      ### Metadata
      ${l.concatMapStrings (key: "- ${key}: ${dataset.metadata.${key}}\n") 
        (l.attrNames dataset.metadata)}
      ''}
      
      ---
    '') datasetsRegistry;
  in ''
    # Datasets Registry
    
    This document contains information about all available datasets.
    
    ${l.concatStringsSep "\n" datasetsList}
  '';
  
in {
  registry = datasetsRegistry;
  documentation = allDatasetsDocs;
  
  # Helper function to resolve dataset references in pipeline inputs
  resolveDatasetReferences = pipelineInputs: 
    l.map (input: 
      if l.hasPrefix "dataset:" input then
        let
          datasetName = l.removePrefix "dataset:" input;
        in
          if l.hasAttr datasetName datasetsRegistry then
            datasetsRegistry.${datasetName}.path
          else
            throw "Dataset not found: ${datasetName}"
      else
        input
    ) pipelineInputs;
}