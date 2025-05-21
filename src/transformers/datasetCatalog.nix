{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Extract catalog definition with defaults
  catalog = transformers.withDefaults config {
    datasets = {};
    categories = [];
    tags = [];
  };
  
  # Generate JSON catalog file
  catalogJson = pkgs.writeTextFile {
    name = "${catalog.name}-catalog.json";
    text = transformers.toJSON {
      name = catalog.name;
      description = catalog.description;
      datasets = catalog.datasets;
      categories = catalog.categories;
      tags = catalog.tags;
    };
  };
  
  # Generate documentation using the transformers library
  catalogDocs = transformers.generateDocs {
    name = "Dataset Catalog: ${catalog.name}";
    description = catalog.description;
    usage = ''
      ```bash
      # Search the catalog
      search-catalog-${catalog.name} SEARCH_TERM
      ```
    '';
    examples = ''
      ```bash
      # Search for datasets related to "image"
      search-catalog-${catalog.name} image
      
      # Search for datasets with a specific license
      search-catalog-${catalog.name} MIT
      ```
    '';
    params = {
      datasets = {
        description = "Collection of datasets in the catalog";
        type = "attrset";
        value = catalog.datasets;
      };
      categories = {
        description = "Categories for organizing datasets";
        type = "list";
        value = catalog.categories;
      };
      tags = {
        description = "Tags for filtering datasets";
        type = "list";
        value = catalog.tags;
      };
    };
  };
  
  # Create a command to search the catalog using the transformers library
  searchScript = transformers.withArgs {
    name = "search-catalog-${catalog.name}";
    description = "Search the ${catalog.name} dataset catalog";
    args = [
      { name = "SEARCH_TERM"; description = "Term to search for in dataset names, descriptions, and tags"; required = true; position = 0; }
    ];
  } ''
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
  
  # Create derivations using the transformers library
  searchDrv = transformers.mkScript {
    name = "search-catalog-${catalog.name}";
    description = "Search the ${catalog.name} dataset catalog";
    script = searchScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${catalog.name}-catalog";
    content = catalogDocs;
  };
  
in {
  # Original catalog configuration
  inherit (catalog) name description datasets categories tags;
  
  # Derivations
  json = catalogJson;
  documentation = docsDrv;
  search = searchDrv;
  
  # Add metadata
  metadata = catalog.metadata or {};
}
