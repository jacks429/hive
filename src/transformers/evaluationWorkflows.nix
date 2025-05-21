{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract all components from the evaluation workflow
  dataLoader = config.dataLoader;
  model = config.model;
  metrics = config.metrics;
  
  # Get registries
  dataLoadersRegistry = root.collectors.dataLoadersConfigurations (cell: target: "${cell}-${target}");
  pipelinesRegistry = root.collectors.pipelinesConfigurations (cell: target: "${cell}-${target}");
  modelsRegistry = root.collectors.modelRegistryConfigurations (cell: target: "${cell}-${target}");
  
  # Validate component references
  validateDataLoader = 
    if !(l.hasAttr dataLoader dataLoadersRegistry) then
      throw "Evaluation workflow ${config.name} references non-existent data loader: ${dataLoader}"
    else
      true;
  
  validateModel =
    if !(l.hasAttr model pipelinesRegistry) && !(l.hasAttr model modelsRegistry) then
      throw "Evaluation workflow ${config.name} references non-existent model/pipeline: ${model}"
    else
      true;
  
  # Check that component references are valid
  _ = validateDataLoader && validateModel;
  
  # Generate Mermaid diagram for documentation
  mermaidDiagram = ''
    flowchart TD
      dataLoader["${dataLoader}"]
      model["${model}"]
      ${l.concatMapStrings (metric: ''
        ${metric}["${metric}"]
      '') metrics}
      
      dataLoader --> model
      ${l.concatMapStrings (metric: ''
        model --> ${metric}
      '') metrics}
  '';
  
  # Generate DOT diagram for visualization
  dotDiagram = ''
    digraph "${config.name}" {
      rankdir=LR;
      node [shape=box, style=filled, fillcolor=lightblue];
      
      "dataLoader" [label="${dataLoader}", fillcolor=lightgreen];
      "model" [label="${model}", fillcolor=lightyellow];
      ${l.concatMapStrings (metric: ''
        "${metric}" [label="${metric}", fillcolor=lightpink];
      '') metrics}
      
      "dataLoader" -> "model";
      ${l.concatMapStrings (metric: ''
        "model" -> "${metric}";
      '') metrics}
    }
  '';
  
  # Generate execution script
  executionScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Starting evaluation workflow: ${config.name}"
    echo "${config.description}"
    
    # Step 1: Run data loader
    echo "Running data loader: ${dataLoader}"
    nix run .#run-${dataLoader}
    
    # Step 2: Run model/pipeline
    echo "Running model/pipeline: ${model}"
    nix run .#run-${model}
    
    # Step 3: Run evaluation metrics
    ${l.concatMapStrings (metric: ''
      echo "Running evaluation metric: ${metric}"
      nix run .#run-${metric} -- --input ${config.modelOutput} --reference ${config.referenceData} --output ${config.name}-${metric}-results.json
    '') metrics}
    
    # Step 4: Generate combined report
    echo "Generating evaluation report"
    cat > ${config.name}-report.md << EOL
    # Evaluation Report: ${config.name}
    
    ## Overview
    - Data Loader: \`${dataLoader}\`
    - Model/Pipeline: \`${model}\`
    - Evaluation Date: \$(date)
    
    ## Metrics
    ${l.concatMapStrings (metric: ''
    ### ${metric}
    \`\`\`
    \$(cat ${config.name}-${metric}-results.json)
    \`\`\`
    
    '') metrics}
    EOL
    
    echo "Evaluation workflow completed. Report available at ${config.name}-report.md"
  '';
  
  # Generate documentation
  documentation = ''
    # Evaluation Workflow: ${config.name}
    
    ${config.description}
    
    ## Components
    
    This evaluation workflow consists of the following components:
    
    1. **Data Loader**: ${dataLoader}
    2. **Model/Pipeline**: ${model}
    3. **Evaluation Metrics**: ${l.concatStringsSep ", " metrics}
    
    ## Diagram
    
    ```mermaid
    ${mermaidDiagram}
    ```
    
    ## Execution
    
    To run this evaluation workflow, use:
    
    ```bash
    nix run .#evaluate-${config.name}
    ```
    
    ## Output
    
    The evaluation results will be saved to:
    
    ${l.concatMapStrings (metric: ''
    - `${config.name}-${metric}-results.json`
    '') metrics}
    
    And a combined report will be generated at:
    
    - `${config.name}-report.md`
  '';
  
  # Return the processed evaluation workflow with generated outputs
  result = config // {
    mermaidDiagram = mermaidDiagram;
    dotDiagram = dotDiagram;
    executionScript = executionScript;
    documentation = documentation;
  };
in
  result