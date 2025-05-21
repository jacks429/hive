{
  nixpkgs,
  root,
  inputs,
}: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${builtins.currentSystem};
  
  # Get all taxonomies
  taxonomies = root.collectors.taxonomies (cell: target: "${cell}-${target}");
  
  # Generate markdown documentation for a single taxonomy
  generateTaxonomyDoc = name: taxonomy: ''
    # Taxonomy: ${name}
    
    ${taxonomy.description}
    
    ## Format
    
    This taxonomy uses the **${taxonomy.format}** format.
    
    ## Categories
    
    ${let
      renderCategory = indent: name: node:
        ''
        ${indent}- **${name}**: ${node.description or ""}
        '' + 
        (if node ? children then
          l.concatStringsSep "" (l.mapAttrsToList (childName: childNode:
            renderCategory "${indent}  " childName childNode
          ) node.children)
        else "");
    in
      l.concatStringsSep "" (l.mapAttrsToList (name: node:
        renderCategory "" name node
      ) taxonomy.categories)}
    
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
          command = ''
            nix run .#use-taxonomy-${name} -- $INPUT_FILE $OUTPUT_FILE
          '';
        }
      ];
    }
    ```
  '';
  
  # Generate combined documentation for all taxonomies
  allTaxonomiesDocs = ''
    # Taxonomies
    
    This document provides an overview of all available taxonomies.
    
    ## Available Taxonomies
    
    ${l.concatStringsSep "\n" (l.mapAttrsToList (name: _:
      "- [${name}](#taxonomy-${name})"
    ) taxonomies)}
    
    ${l.concatStringsSep "\n\n---\n\n" (l.mapAttrsToList (name: taxonomy:
      generateTaxonomyDoc name taxonomy
    ) taxonomies)}
  '';
  
  # Create a derivation for the documentation
  docsDrv = pkgs.writeTextFile {
    name = "taxonomies-documentation";
    text = allTaxonomiesDocs;
    destination = "/share/taxonomies/documentation.md";
  };
  
  # Create HTML documentation
  htmlDocsDrv = pkgs.runCommand "taxonomies-html-docs" {} ''
    mkdir -p $out/share/taxonomies
    ${pkgs.pandoc}/bin/pandoc -f markdown -t html \
      -o $out/share/taxonomies/documentation.html \
      ${docsDrv}/share/taxonomies/documentation.md
  '';
  
in {
  # Documentation derivations
  markdown = docsDrv;
  html = htmlDocsDrv;
  
  # Raw documentation text
  text = allTaxonomiesDocs;
}