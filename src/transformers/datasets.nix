{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract dataset definition
  dataset = config;
  
  # Process dataset based on type
  processedDataset = 
    if dataset.type == "file" then processFileDataset dataset
    else if dataset.type == "url" then processUrlDataset dataset
    else if dataset.type == "derivation" then processDerivationDataset dataset
    else dataset; # Pass through if type is unknown
  
  # Process file-based dataset
  processFileDataset = dataset: dataset // {
    # Resolve path relative to project root if not absolute
    resolvedPath = 
      if l.hasPrefix "/" dataset.path
      then dataset.path
      else "${toString inputs.self}/${dataset.path}";
      
    # Add validation function
    validate = ''
      if [ ! -f "${dataset.resolvedPath}" ]; then
        echo "❌ Dataset file not found: ${dataset.path}"
        exit 1
      fi
      
      ${l.optionalString (dataset ? hash) ''
        echo "🔍 Validating file hash..."
        ACTUAL_HASH=$(sha256sum "${dataset.resolvedPath}" | cut -d ' ' -f 1)
        if [ "$ACTUAL_HASH" != "${dataset.hash}" ]; then
          echo "❌ Hash mismatch for ${dataset.path}"
          echo "Expected: ${dataset.hash}"
          echo "Actual: $ACTUAL_HASH"
          exit 1
        fi
      ''}
      
      echo "✅ Dataset validated: ${dataset.name}"
    '';
  };
  
  # Process URL-based dataset
  processUrlDataset = dataset: dataset // {
    # Create a derivation that fetches the URL
    fetched = pkgs.fetchurl {
      url = dataset.url;
      sha256 = dataset.hash;
    };
    
    # Add validation function
    validate = ''
      echo "✅ Dataset validated: ${dataset.name} (URL hash verified by Nix)"
    '';
  };
  
  # Process derivation-based dataset
  processDerivationDataset = dataset: dataset // {
    # Reference the derivation directly
    derivation = dataset.derivation;
    
    # Add validation function
    validate = ''
      echo "✅ Dataset validated: ${dataset.name} (derivation verified by Nix)"
    '';
  };
  
in {
  # Original dataset data
  inherit (dataset) name system type description;
  
  # Type-specific fields
  inherit (processedDataset) 
    ${l.optionalString (dataset.type == "file") "resolvedPath"}
    ${l.optionalString (dataset.type == "url") "fetched"}
    ${l.optionalString (dataset.type == "derivation") "derivation"};
  
  # Add validation function
  validate = processedDataset.validate;
  
  # Add metadata for dataset usage
  metadata = dataset.metadata or {};
  
  # Generate path for use in pipelines
  path = 
    if dataset.type == "file" then processedDataset.resolvedPath
    else if dataset.type == "url" then processedDataset.fetched
    else if dataset.type == "derivation" then "${processedDataset.derivation}";
}
