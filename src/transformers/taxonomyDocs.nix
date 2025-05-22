{
  nixpkgs,
  root,
  inputs,
}: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${builtins.currentSystem};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Get all taxonomies
  taxonomies = root.collectors.taxonomies (cell: target: "${cell}-${target}");
  
  # Generate markdown documentation for a single taxonomy
  generateTaxonomyDoc = name: taxonomy: ''
    # Taxonomy: ${name}
    
    ${taxonomy.description or "No description provided"}
    
    ## Format
    
    This taxonomy uses the **${taxonomy.format or "unknown"}** format.
    
    ## Categories
    
    ${let
      renderCategory = indent: catName: node:
        ''
        ${indent}- **${catName}**: ${node.description or ""}
        '' + 
        (if node ? children then
          l.concatStringsSep "" (l.mapAttrsToList (childName: childNode:
            renderCategory "${indent}  " childName childNode
          ) node.children)
        else "");
    in
      l.concatStringsSep "" (l.mapAttrsToList (catName: node:
        renderCategory "" catName node
      ) taxonomy.categories or {})}
    
    ## Metadata
    
    ${l.concatStringsSep "\n" (l.mapAttrsToList (key: value:
      "- **${key}**: ${toString value}"
    ) (taxonomy.metadata or {}))}
    
    ## Usage
    
    ```nix
    # Reference in a pipeline
    {
      inputs,
      cell,
    }: {
      name = "my-classification-pipeline";
      steps = [
        {
          name = "classify-with-taxonomy";
          command = "nix run .#use-taxonomy-${name} -- $INPUT_FILE $OUTPUT_FILE";
        }
      ];
    }
    ```
  '';
  
  # Generate combined documentation for all taxonomies using the transformers library
  allTaxonomiesDocs = transformers.generateDocs {
    name = "Taxonomies";
    description = "This document provides an overview of all available taxonomies.";
    usage = ''
      ```nix
      # Reference in your code
      {
        inputs,
        cell,
      }: {
        # Use the taxonomy documentation
        inherit (inputs.hive.taxonomyDocs) markdown html;
      }
      ```
    '';
    examples = ''
      ```bash
      # View the documentation
      nix run .#view-taxonomy-docs
      ```
    '';
    params = {
      taxonomies = {
        description = "Available taxonomies";
        type = "attrset";
        value = l.mapAttrs (name: _: name) taxonomies;
      };
    };
  } + "\n\n" + ''
    ## Available Taxonomies
    
    ${l.concatStringsSep "\n" (l.mapAttrsToList (name: _:
      "- [${name}](#taxonomy-${name})"
    ) taxonomies)}
    
    ${l.concatStringsSep "\n\n---\n\n" (l.mapAttrsToList (name: taxonomy:
      generateTaxonomyDoc name taxonomy
    ) taxonomies)}
  '';
  
  # Create a derivation for the documentation using the transformers library
  docsDrv = transformers.mkDocs {
    name = "taxonomies";
    content = allTaxonomiesDocs;
  };
  
  # Create HTML documentation
  htmlDocsDrv = pkgs.runCommand "taxonomies-html-docs" {} ''
    mkdir -p $out/share/taxonomies
    ${pkgs.pandoc}/bin/pandoc -f markdown -t html \
      -o $out/share/taxonomies/documentation.html \
      ${docsDrv}/share/doc/taxonomies.md
  '';
  
  # Create a script to view the documentation using the transformers library
  viewScript = transformers.withArgs {
    name = "view-taxonomy-docs";
    description = "View taxonomy documentation";
  } ''
    echo "Opening taxonomy documentation..."
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy the documentation
    cp ${docsDrv}/share/doc/taxonomies.md $TEMP_DIR/taxonomies.md
    
    # Convert to HTML
    ${pkgs.pandoc}/bin/pandoc -f markdown -t html \
      -o $TEMP_DIR/taxonomies.html \
      $TEMP_DIR/taxonomies.md
    
    # Open in browser
    ${pkgs.xdg-utils}/bin/xdg-open $TEMP_DIR/taxonomies.html
  '';
  
  # Create view script derivation using the transformers library
  viewDrv = transformers.mkScript {
    name = "view-taxonomy-docs";
    description = "View taxonomy documentation";
    script = viewScript;
  };
  
in {
  # Documentation derivations
  markdown = docsDrv;
  html = htmlDocsDrv;
  view = viewDrv;
  
  # Raw documentation text
  text = allTaxonomiesDocs;
}
