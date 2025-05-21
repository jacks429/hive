{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all taxonomies
  taxonomies = root.collectors.taxonomies renamer;
  
  # Create a registry of taxonomy definitions, keyed by name
  taxonomiesRegistry = l.mapAttrs (name: taxonomy: {
    inherit (taxonomy) name description format categories metadata;
  }) taxonomies;
  
  # Function to get a taxonomy by name
  getTaxonomy = name:
    if l.hasAttr name taxonomiesRegistry
    then taxonomiesRegistry.${name}
    else throw "Taxonomy not found: ${name}";
  
  # Generate combined documentation for all taxonomies
  allTaxonomiesDocs = let
    taxonomiesList = l.mapAttrsToList (name: taxonomy: ''
      ## Taxonomy: ${name}
      
      ${taxonomy.description}
      
      - **Format**: ${taxonomy.format}
      ${l.optionalString (taxonomy ? metadata) ''
      - **Metadata**:
        ${l.concatMapStrings (key: "  - ${key}: ${taxonomy.metadata.${key}}\n") 
          (l.attrNames taxonomy.metadata)}
      ''}
      
      ---
    '') taxonomiesRegistry;
  in ''
    # Taxonomies Registry
    
    This document contains information about all available taxonomies.
    
    ${l.concatStringsSep "\n" taxonomiesList}
  '';
  
in {
  registry = taxonomiesRegistry;
  getTaxonomy = getTaxonomy;
  documentation = allTaxonomiesDocs;
}