{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "evaluationWorkflows";
  type = "evaluation-workflow";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    evalWorkflow = inputs.${fragment}.${target};
    
    # Generate evaluation visualization
    generateVisualization = ''
      mkdir -p $PRJ_ROOT/evaluation-workflows
      cat > $PRJ_ROOT/evaluation-workflows/${target}.dot << EOF
      digraph "${evalWorkflow.name}" {
        rankdir=LR;
        node [shape=box, style=filled, fillcolor=lightblue];
        
        # Data loading stage
        "data-loading" [label="Data Loading", fillcolor=lightgreen];
        
        # Model/pipeline stage
        "model-execution" [label="Model Execution", fillcolor=lightyellow];
        
        # Evaluation metrics stage
        ${l.concatMapStrings (metric: ''
          "${metric}" [label="${metric}", fillcolor=lightpink];
        '') evalWorkflow.metrics}
        
        # Connect stages
        "data-loading" -> "model-execution";
        ${l.concatMapStrings (metric: ''
          "model-execution" -> "${metric}";
        '') evalWorkflow.metrics}
      }
      EOF
      ${pkgs.graphviz}/bin/dot -Tsvg $PRJ_ROOT/evaluation-workflows/${target}.dot -o $PRJ_ROOT/evaluation-workflows/${target}.svg
      echo "Evaluation workflow visualization generated at evaluation-workflows/${target}.svg"
    '';
    
    # Generate execution script
    generateExecutionScript = ''
      cat > $PRJ_ROOT/evaluation-workflows/${target}-run.sh << EOF
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "Starting evaluation workflow: ${evalWorkflow.name}"
      
      # Step 1: Run data loader
      echo "Running data loader: ${evalWorkflow.dataLoader}"
      nix run .#run-${evalWorkflow.dataLoader}
      
      # Step 2: Run model/pipeline
      echo "Running model/pipeline: ${evalWorkflow.model}"
      nix run .#run-${evalWorkflow.model}
      
      # Step 3: Run evaluation metrics
      ${l.concatMapStrings (metric: ''
        echo "Running evaluation metric: ${metric}"
        nix run .#run-${metric} -- --input ${evalWorkflow.modelOutput} --reference ${evalWorkflow.referenceData} --output evaluation-workflows/${target}-${metric}-results.json
      '') evalWorkflow.metrics}
      
      # Step 4: Generate combined report
      echo "Generating evaluation report"
      cat > evaluation-workflows/${target}-report.md << EOL
      # Evaluation Report: ${evalWorkflow.name}
      
      ## Overview
      - Data Loader: \`${evalWorkflow.dataLoader}\`
      - Model/Pipeline: \`${evalWorkflow.model}\`
      - Evaluation Date: \$(date)
      
      ## Metrics
      ${l.concatMapStrings (metric: ''
      ### ${metric}
      \`\`\`
      \$(cat evaluation-workflows/${target}-${metric}-results.json)
      \`\`\`
      
      '') evalWorkflow.metrics}
      EOL
      
      echo "Evaluation workflow completed. Report available at evaluation-workflows/${target}-report.md"
      EOF
      chmod +x $PRJ_ROOT/evaluation-workflows/${target}-run.sh
      echo "Evaluation workflow execution script generated at evaluation-workflows/${target}-run.sh"
    '';
  in [
    (mkCommand currentSystem {
      name = "visualize";
      description = "Generate evaluation workflow visualization";
      command = generateVisualization;
    })
    (mkCommand currentSystem {
      name = "generate";
      description = "Generate evaluation workflow execution script";
      command = generateExecutionScript;
    })
    (mkCommand currentSystem {
      name = "run";
      description = "Run the evaluation workflow";
      command = "$PRJ_ROOT/evaluation-workflows/${target}-run.sh";
    })
    (mkCommand currentSystem {
      name = "report";
      description = "View the evaluation report";
      command = "cat $PRJ_ROOT/evaluation-workflows/${target}-report.md";
    })
  ];
}