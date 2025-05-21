{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract catalog definition
  catalog = {
    inherit (config) name description;
    datasets = config.datasets or {};
    categories = config.categories or [];
    tags = config.tags or [];
  };
  
  # Generate JSON catalog file
  catalogJson = pkgs.writeTextFile {
    name = "${catalog.name}-catalog.json";
    text = builtins.toJSON {
      name = catalog.name;
      description = catalog.description;
      datasets = catalog.datasets;
      categories = catalog.categories;
      tags = catalog.tags;
    };
  };
  
  # Generate markdown documentation
  catalogMd = pkgs.writeTextFile {
    name = "${catalog.name}-catalog.md";
    text = ''
      # Dataset Catalog: ${catalog.name}
      
      ${catalog.description}
      
      ## Categories
      
      ${l.concatMapStrings (category: ''
      - ${category}
      '') catalog.categories}
      
      ## Datasets
      
      ${l.concatMapStrings (name: let dataset = catalog.datasets.${name}; in ''
      ### ${name}
      
      ${dataset.description or ""}
      
      - **Format**: ${dataset.format or "Unknown"}
      - **Size**: ${dataset.size or "Unknown"}
      - **Tags**: ${l.concatStringsSep ", " (dataset.tags or [])}
      - **License**: ${dataset.license or "Unknown"}
      
      ${dataset.notes or ""}
      
      '') (builtins.attrNames catalog.datasets)}
    '';
  };
  
  # Create a command to search the catalog
  searchScript = pkgs.writeShellScriptBin "search-catalog-${catalog.name}" ''
    #!/usr/bin/env bash
    
    if [ $# -lt 1 ]; then
      echo "Usage: search-catalog-${catalog.name} SEARCH_TERM"
      exit 1
    fi
    
    SEARCH_TERM="$1"
    CATALOG_FILE="${catalogJson}"
    
    echo "Searching catalog '${catalog.name}' for: $SEARCH_TERM"
    echo ""
    
    # Use jq to search the catalog
    ${pkgs.jq}/bin/jq -r --arg term "$SEARCH_TERM" '
    .datasets | to_entries[] | 
    select(
      .key | contains($term) or
      .value.description | contains($term) or
      (.value.tags | join(" ") | contains($term))
    ) | 
    "Dataset: \(.key)\nDescription: \(.value.description)\nFormat: \(.value.format)\nTags: \(.value.tags | join(", "))\n"
    ' "$CATALOG_FILE"
  '';
  
in {
  # Original catalog configuration
  inherit (catalog) name description datasets categories tags;
  
  # Derivations
  json = catalogJson;
  documentation = catalogMd;
  search = searchScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
