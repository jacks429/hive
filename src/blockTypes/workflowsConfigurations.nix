{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;

  workflows = {
    name = "workflows";
    type = "workflow";
    transform = import ../transformers/workflowsConfigurations.nix;
    
    actions = {
      currentSystem,
      fragment,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
      workflow = inputs.${fragment}.${target};
      
      # Generate documentation
      generateDocs = ''
        cat > workflow-${target}.md << EOF
        # Workflow: ${target}
        
        ${workflow.description}
        
        ## Pipelines
        ${l.concatMapStrings (pipeline: 
          let deps = workflow.dependencies.${pipeline}; in
          "- ${pipeline} (depends on: ${if deps == [] then "none" else l.concatStringsSep ", " deps})\n"
        ) workflow.pipelines}
        
        ## Dependency Graph
        
        \`\`\`mermaid
        ${workflow.mermaidDiagram}
        \`\`\`
        
        ${l.optionalString (workflow ? metadata) ''
        ## Metadata
        ${l.concatMapStrings (key: "- ${key}: ${workflow.metadata.${key}}\n") 
          (l.attrNames workflow.metadata)}
        ''}
        EOF
        
        echo "Documentation generated at workflow-${target}.md"
      '';
    in [
      (mkCommand currentSystem {
        name = "run";
        description = "Run the workflow";
        command = "${workflow.runner}/bin/run-workflow-${workflow.name}";
      })
      (mkCommand currentSystem {
        name = "docs";
        description = "Generate workflow documentation";
        command = generateDocs;
      })
      (mkCommand currentSystem {
        name = "visualize";
        description = "Visualize the workflow dependency graph";
        command = ''
          # Generate Mermaid diagram
          cat > workflow-${target}.mmd << EOF
          ${workflow.mermaidDiagram}
          EOF
          
          # Try to render with mermaid-cli if available
          if command -v mmdc &> /dev/null; then
            mmdc -i workflow-${target}.mmd -o workflow-${target}.png
            echo "Workflow visualization saved to workflow-${target}.png"
          else
            echo "Mermaid CLI not found. Mermaid file saved to workflow-${target}.mmd"
            echo "View online at https://mermaid.live"
          fi
        '';
      })
    ];
  };
in
  workflows