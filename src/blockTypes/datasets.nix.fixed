{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;

  datasets = {
    name = "datasets";
    type = "dataset";
    transform = import ../transformers/datasetsConfigerations.nix;
    
    actions = {
      currentSystem,
      fragment,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
      dataset = inputs.${fragment}.${target};
      
      # Generate documentation
      generateDocs = ''
        cat > dataset-${target}.md << EOF
        # Dataset: ${target}
        
        ${dataset.description}
        
        ## Type
        ${dataset.type}
        
        ## System
        ${dataset.system}
        
        ## Path
        \`${dataset.path}\`
        
        ${l.optionalString (dataset ? metadata) ''
        ## Metadata
        ${l.concatMapStrings (key: "- ${key}: ${dataset.metadata.${key}}\n") 
          (l.attrNames dataset.metadata)}
        ''}
        EOF
        
        echo "Documentation generated at dataset-${target}.md"
      '';
    in [
      (mkCommand currentSystem {
        name = "validate";
        description = "Validate the dataset";
        command = dataset.validate;
      })
      (mkCommand currentSystem {
        name = "docs";
        description = "Generate dataset documentation";
        command = generateDocs;
      })
      (mkCommand currentSystem {
        name = "path";
        description = "Print the path to the dataset";
        command = ''
          echo "${dataset.path}"
        '';
      })
    ];
  };
in
  datasets
