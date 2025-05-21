{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract taxonomy definition
  taxonomy = config;
  
  # Process the taxonomy structure
  processedCategories = 
    if taxonomy.format == "hierarchical" then
      # Process hierarchical taxonomy
      taxonomy.categories
    else if taxonomy.format == "flat" then
      # Convert flat list to hierarchical structure
      let
        flatToHierarchical = flatList:
          l.foldl' (acc: item:
            let
              path = l.splitString "/" item.path;
              insertPath = remaining: struct: name:
                if remaining == [] then
                  struct // { ${name} = struct.${name} or {} // { isLeaf = true; }; }
                else
                  let
                    next = l.head remaining;
                    rest = l.tail remaining;
                    children = struct.${name}.children or {};
                  in
                    struct // {
                      ${name} = struct.${name} or {} // {
                        children = insertPath rest children next;
                      };
                    };
            in
              insertPath (l.tail path) acc (l.head path)
          ) {} flatList;
      in
        flatToHierarchical taxonomy.categories
    else
      taxonomy.categories;
  
  # Generate JSON representation
  jsonOutput = builtins.toJSON processedCategories;
  
  # Create a derivation for the taxonomy
  taxonomyDrv = pkgs.writeTextFile {
    name = "taxonomy-${taxonomy.name}";
    text = jsonOutput;
    destination = "/share/taxonomies/${taxonomy.name}.json";
  };
  
  # Create a script to compile the taxonomy
  compileTaxonomyScriptDrv = pkgs.writeShellScriptBin "compile-taxonomy-${taxonomy.name}" ''
    mkdir -p $PRJ_ROOT/taxonomies
    cp ${taxonomyDrv}/share/taxonomies/${taxonomy.name}.json $PRJ_ROOT/taxonomies/
    echo "Taxonomy compiled to taxonomies/${taxonomy.name}.json"
  '';
  
  # Create a script to use the taxonomy in pipelines
  useTaxonomyScriptDrv = pkgs.writeShellScriptBin "use-taxonomy-${taxonomy.name}" ''
    if [ -z "$1" ]; then
      echo "Usage: use-taxonomy-${taxonomy.name} <input-file> <output-file>"
      exit 1
    fi
    
    INPUT_FILE="$1"
    OUTPUT_FILE="$2"
    
    # Load the taxonomy
    TAXONOMY_FILE="$PRJ_ROOT/taxonomies/${taxonomy.name}.json"
    if [ ! -f "$TAXONOMY_FILE" ]; then
      echo "Taxonomy file not found. Compiling..."
      ${compileTaxonomyScriptDrv}/bin/compile-taxonomy-${taxonomy.name}
    fi
    
    # Process input using the taxonomy
    ${pkgs.jq}/bin/jq --slurpfile taxonomy "$TAXONOMY_FILE" \
      '{ input: ., taxonomy: $taxonomy[0] }' "$INPUT_FILE" > "$OUTPUT_FILE"
  '';
  
  # Generate documentation
  documentation = ''
    # Taxonomy: ${taxonomy.name}
    
    ${taxonomy.description}
    
    ## Format
    
    This taxonomy uses the **${taxonomy.format}** format.
    
    ## Usage
    
    ### Compile the taxonomy
    
    ```bash
    nix run .#compile-taxonomy-${taxonomy.name}
    ```
    
    This will create the taxonomy file at `taxonomies/${taxonomy.name}.json`.
    
    ### Use the taxonomy in a pipeline
    
    ```bash
    nix run .#use-taxonomy-${taxonomy.name} -- input.json output.json
    ```
    
    ## Structure
    
    ```json
    ${jsonOutput}
    ```
  '';
  
  documentationDrv = pkgs.writeTextFile {
    name = "taxonomy-docs-${taxonomy.name}";
    text = documentation;
    destination = "/share/taxonomies/docs/${taxonomy.name}.md";
  };
  
  # Create a package with all taxonomy artifacts
  taxonomyPackageDrv = pkgs.symlinkJoin {
    name = "taxonomy-package-${taxonomy.name}";
    paths = [
      taxonomyDrv
      compileTaxonomyScriptDrv
      useTaxonomyScriptDrv
      documentationDrv
    ];
  };
  
in {
  # Original taxonomy configuration
  inherit (taxonomy) name description format;
  inherit (taxonomy) system;
  
  # Processed content
  categories = processedCategories;
  
  # Derivations
  taxonomy = taxonomyDrv;
  compiler = compileTaxonomyScriptDrv;
  processor = useTaxonomyScriptDrv;
  docs = documentationDrv;
  package = taxonomyPackageDrv;
  
  # Metadata
  metadata = taxonomy.metadata // {
    type = "taxonomy";
  };
}