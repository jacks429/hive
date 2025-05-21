{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;

  pipelines = {
    name = "pipelines";
    type = "pipeline";
    transform = import ../transformers/pipelines.nix;
    
    actions = {
      currentSystem,
      fragment,
      fragmentRelPath,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
      pipeline = inputs.${fragment}.${target};
      
      # Generate documentation
      generateDocs = ''
        cat > pipeline-${target}.md << EOF
        # Pipeline: ${target}
        
        ${pipeline.description}
        
        ## Inputs
        ${l.concatMapStrings (input: "- ${input}\n") pipeline.inputs}
        
        ## Outputs
        ${l.concatMapStrings (output: "- ${output}\n") pipeline.outputs}
        
        ## Services
        ${l.concatMapStrings (service: "- ${service}\n") pipeline.services}
        
        ## Resources
        ${l.concatMapStrings (name: "- ${name}: ${pipeline.resources.${name}}\n") 
          (l.attrNames pipeline.resources)}
        
        ## Dependency Graph
        
        \`\`\`mermaid
        ${pipeline.mermaidDiagram}
        \`\`\`
        
        ## Steps
        
        ${l.concatMapStrings (step: ''
          ### ${step.name}
          
          Dependencies: ${if step.depends == [] then "None" else l.concatStringsSep ", " step.depends}
          
          \`\`\`bash
          ${step.command}
          \`\`\`
          
        '') pipeline.steps}
        EOF
        
        echo "Documentation generated at pipeline-${target}.md"
      '';
    in [
      (mkCommand currentSystem {
        name = "run";
        description = "Run the pipeline";
        command = ''
          ${pipeline.runner}/bin/run-${pipeline.name}
        '';
      })
      (mkCommand currentSystem {
        name = "docs";
        description = "Generate pipeline documentation";
        command = generateDocs;
      })
      (mkCommand currentSystem {
        name = "visualize";
        description = "Visualize the pipeline dependency graph";
        command = ''
          # Generate Mermaid diagram
          cat > pipeline-${target}.mmd << EOF
          ${pipeline.mermaidDiagram}
          EOF
          
          # Try to render with mermaid-cli if available
          if command -v mmdc &> /dev/null; then
            mmdc -i pipeline-${target}.mmd -o pipeline-${target}.png
            echo "Pipeline visualization saved to pipeline-${target}.png"
          else
            echo "Mermaid CLI not found. Mermaid file saved to pipeline-${target}.mmd"
            echo "View online at https://mermaid.live"
          fi
        '';
      })
    ];
  };
in
  pipelines