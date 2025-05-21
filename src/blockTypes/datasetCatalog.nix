{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "datasetCatalog";
  type = "datasetCatalog";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    dataset = inputs.${fragment}.${target};
    
    # Generate markdown documentation
    generateMarkdown = pkgs.writeTextFile {
      name = "${target}-dataset.md";
      text = ''
        # Dataset: ${dataset.name}
        
        ${dataset.description}
        
        ## Overview
        
        - **URI:** ${dataset.uri}
        - **License:** ${dataset.license}
        - **SHA256:** ${dataset.sha256}
        - **Maintainer:** ${dataset.maintainer}
        
        ## Lineage
        
        ${l.concatMapStrings (step: "- ${step}\n") dataset.lineage}
        
        ## Tags
        
        ${l.concatMapStrings (tag: "- ${tag}\n") dataset.tags}
      '';
    };
    
  in [];  # No commands, just metadata for the catalog
}