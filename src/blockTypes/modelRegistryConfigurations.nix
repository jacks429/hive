{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;

  modelRegistry = {
    name = "modelRegistry";
    type = "model-registry";
    transform = import ../transformers/modelRegistryConfigurations.nix;
    
    actions = {
      currentSystem,
      fragment,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
      model = inputs.${fragment}.${target};
      
      # Generate documentation
      generateDocs = ''
        cat > model-${target}.md << EOF
        # Model: ${model.name} (version ${model.version})
        
        ${model.description}
        
        ## Overview
        
        - **Framework:** ${model.framework}
        - **Pipeline:** ${model.pipeline or "N/A"}
        - **Artifact:** ${model.artifact or "N/A"}
        
        ## Metrics
        
        ${l.concatMapStrings (key: "- **${key}:** ${l.toJSON model.metrics.${key}}\n") 
          (l.attrNames (model.metrics or {}))}
        
        ## Lineage
        
        ${l.concatMapStrings (key: "- **${key}:** ${l.toJSON model.lineage.${key}}\n") 
          (l.attrNames (model.lineage or {}))}
        
        EOF
      '';
      
      # Create a script to print model info
      infoScript = ''
        echo "Model: ${model.name} (version ${model.version})"
        echo "Framework: ${model.framework}"
        echo "Pipeline: ${model.pipeline or "N/A"}"
        echo "Artifact: ${model.artifact or "N/A"}"
        echo ""
        echo "Metrics:"
        ${l.concatMapStrings (key: "echo \"  ${key}: ${l.toJSON model.metrics.${key}}\"\n") 
          (l.attrNames (model.metrics or {}))}
        echo ""
        echo "Lineage:"
        ${l.concatMapStrings (key: "echo \"  ${key}: ${l.toJSON model.lineage.${key}}\"\n") 
          (l.attrNames (model.lineage or {}))}
      '';
      
    in [
      (mkCommand currentSystem {
        name = "info";
        description = "Show model information";
        command = infoScript;
      })
      (mkCommand currentSystem {
        name = "docs";
        description = "Generate model documentation";
        command = generateDocs;
      })
      (mkCommand currentSystem {
        name = "load";
        description = "Load the model";
        command = ''
          ${model.wrapper}/bin/load-model-${model.name}-${model.version} "$@"
        '';
      })
      (mkCommand currentSystem {
        name = "deploy";
        description = "Deploy the model";
        command = ''
          ${model.deployment}/bin/deploy-model-${model.name}-${model.version} "$@"
        '';
      })
      (mkCommand currentSystem {
        name = "compare";
        description = "Compare with other versions";
        command = ''
          # Get the model registry
          registry=$(nix eval --json .#modelRegistryRegistry)
          
          # Extract model name
          name="${model.name}"
          
          # Get all versions for this model
          versions=$(echo "$registry" | jq -r '.getModelVersions("$name")')
          
          echo "Comparing model: $name"
          echo "Current version: ${model.version}"
          echo "All versions: $versions"
          echo ""
          
          # Compare metrics across versions
          echo "Metrics comparison:"
          echo "===================="
          
          for version in $versions; do
            metrics=$(echo "$registry" | jq -r '.getModel("$name", "$version").metrics')
            echo "Version $version: $metrics"
          done
        '';
      })
    ];
  };
in
  modelRegistry