{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "workflows";
  type = "workflow";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    workflow = inputs.${fragment}.${target};
    
    # Generate workflow visualization
    generateVisualization = ''
      mkdir -p $PRJ_ROOT/workflows
      cat > $PRJ_ROOT/workflows/${target}.dot << EOF
      digraph "${workflow.name}" {
        rankdir=LR;
        node [shape=box, style=filled, fillcolor=lightblue];
        ${l.concatMapStrings (pipeline: ''
          "${pipeline}" [label="${pipeline}"];
        '') workflow.pipelines}
        
        ${l.concatMapStrings (pipeline: 
          l.concatMapStrings (dep: ''
            "${dep}" -> "${pipeline}";
          '') (workflow.dependencies.${pipeline} or [])
        ) workflow.pipelines}
      }
      EOF
      ${pkgs.graphviz}/bin/dot -Tsvg $PRJ_ROOT/workflows/${target}.dot -o $PRJ_ROOT/workflows/${target}.svg
      echo "Workflow visualization generated at workflows/${target}.svg"
    '';
    
    # Generate workflow execution script
    generateExecutionScript = ''
      cat > $PRJ_ROOT/workflows/${target}-run.sh << EOF
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "Starting workflow: ${workflow.name}"
      echo "${workflow.description}"
      
      # Topological sort of pipelines based on dependencies
      function toposort() {
        local -A visited=()
        local -a sorted=()
        
        function visit() {
          local node=\$1
          
          if [[ \${visited[\$node]} == "temp" ]]; then
            echo "Error: Cyclic dependency detected in workflow" >&2
            exit 1
          fi
          
          if [[ -z \${visited[\$node]:-} ]]; then
            visited[\$node]="temp"
            
            ${l.concatMapStrings (pipeline: ''
              if [[ "\$node" == "${pipeline}" ]]; then
                ${l.concatMapStrings (dep: ''
                  visit "${dep}"
                '') (workflow.dependencies.${pipeline} or [])}
              fi
            '') workflow.pipelines}
            
            visited[\$node]="perm"
            sorted=(\$node "\${sorted[@]}")
          fi
        }
        
        ${l.concatMapStrings (pipeline: ''
          visit "${pipeline}"
        '') workflow.pipelines}
        
        echo "\${sorted[@]}"
      }
      
      # Get sorted pipelines
      SORTED_PIPELINES=(\$(toposort))
      
      # Execute pipelines in order
      for pipeline in "\${SORTED_PIPELINES[@]}"; do
        echo "Executing pipeline: \$pipeline"
        nix run .#run-\$pipeline
        
        # Check exit status
        if [ \$? -ne 0 ]; then
          echo "Pipeline \$pipeline failed"
          exit 1
        fi
      done
      
      echo "Workflow ${workflow.name} completed successfully"
      EOF
      chmod +x $PRJ_ROOT/workflows/${target}-run.sh
      echo "Workflow execution script generated at workflows/${target}-run.sh"
    '';
  in [
    (mkCommand currentSystem {
      name = "visualize";
      description = "Generate workflow visualization";
      command = generateVisualization;
    })
    (mkCommand currentSystem {
      name = "generate";
      description = "Generate workflow execution script";
      command = generateExecutionScript;
    })
    (mkCommand currentSystem {
      name = "run";
      description = "Run the workflow";
      command = ''
        mkdir -p $PRJ_ROOT/workflows
        ${generateExecutionScript}
        $PRJ_ROOT/workflows/${target}-run.sh
      '';
    })
  ];
}