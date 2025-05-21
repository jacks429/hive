{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract workflow definition
  workflow = config;
  
  # Get pipelines registry
  pipelinesRegistry = root.collectors.pipelinesConfigurations (cell: target: "${cell}-${target}");
  
  # Validate pipeline references
  validatePipelineReferences = let
    missingPipelines = l.filter (pipeline: 
      !(l.hasAttr pipeline pipelinesRegistry)
    ) workflow.pipelines;
  in
    if missingPipelines != [] then
      throw "Workflow ${workflow.name} references non-existent pipelines: ${l.concatStringsSep ", " missingPipelines}"
    else
      true;
  
  # Check that pipeline references are valid
  _ = validatePipelineReferences;
  
  # Generate Mermaid diagram for documentation
  mermaidDiagram = let
    pipelineDiagrams = l.concatMapStrings (pipeline: 
      if workflow.dependencies.${pipeline} == [] then
        "    start-->\"${pipeline}\"\n"
      else
        l.concatMapStrings (dep:
          "    \"${dep}\"-->\"${pipeline}\"\n"
        ) workflow.dependencies.${pipeline}
    ) workflow.pipelines;
  in ''
    flowchart TD
    ${pipelineDiagrams}
  '';
  
  # Create wrapper script for running the workflow
  runnerScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "🟢 Starting workflow: ${workflow.name}"
    
    # Build dependency graph and execution order
    ${let
      # Get all pipelines
      allPipelines = workflow.pipelines;
      
      # Build dependency graph
      visited = l.foldl' (acc: pipeline: acc // { ${pipeline} = false; }) {} allPipelines;
      sorted = [];
      
      visit = node: visited: sorted:
        if visited.${node} then
          { inherit visited sorted; }
        else
          let
            newVisited = visited // { ${node} = true; };
            deps = workflow.dependencies.${node} or [];
            result = l.foldl'
              (acc: dep: visit dep acc.visited acc.sorted)
              { visited = newVisited; sorted = sorted; }
              deps;
          in {
            visited = result.visited;
            sorted = result.sorted ++ [node];
          };
      
      result = l.foldl'
        (acc: node: 
          if acc.visited.${node} then acc
          else visit node acc.visited acc.sorted
        )
        { inherit visited; sorted = []; }
        allPipelines;
      
      # Generate execution script
      executionScript = l.concatMapStrings (pipeline:
        ''
          echo "▶️ Executing pipeline: ${pipeline}"
          nix run .#run-${pipeline}
          
          # Check exit status
          if [ $? -ne 0 ]; then
            echo "❌ Pipeline ${pipeline} failed"
            exit 1
          fi
          
        ''
      ) result.sorted;
    in executionScript}
    
    echo "✅ Workflow ${workflow.name} completed successfully"
  '';
  
  # Create wrapper derivation
  runnerDrv = pkgs.writeScriptBin "run-workflow-${workflow.name}" runnerScript;
  
  # Add to the existing transformer to support dynamic service endpoints

  # Get service endpoints registry with dynamic resolution
  serviceEndpointsRegistry = root.collectors.serviceEndpointsRegistry (cell: target: "${cell}-${target}");

  # Find endpoints for services used in this workflow
  workflowEndpoints = l.flatten (map (pipeline: 
    let 
      pipelineConfig = pipelineConfigurations.${pipeline};
      pipelineServices = pipelineConfig.services or [];
    in
      map (service: 
        serviceEndpointsRegistry.findEndpoints [{ service = service; }]
      ) pipelineServices
  ) workflow.pipelines);

  # Add endpoints to the workflow configuration
  workflowWithEndpoints = workflow // {
    # Add endpoints information
    endpoints = workflowEndpoints;
    
    # Enhance the runner script to use endpoint configuration
    runner = let
      # Get the original runner script
      originalRunner = workflow.runner;
      
      # Generate additional environment setup for endpoints
      endpointsEnvSetup = l.concatMapStrings (name: endpoint: ''
        # Environment variables for ${name} endpoint
        ${l.concatMapStrings (varName: ''
          export ${varName}="${endpoint.envVars.${varName}}"
        '') (l.attrNames endpoint.envVars)}
        
      '') workflowEndpoints;
      
      # Create a new runner script that includes endpoint information
      newRunnerScript = ''
        #!/usr/bin/env bash
        set -e
        
        # Setup environment variables for service endpoints
        ${endpointsEnvSetup}
        
        # Run the original workflow
        ${originalRunner} "$@"
      '';
      
      # Create a new runner derivation
      newRunnerDrv = pkgs.writeScriptBin "run-workflow-${workflow.name}" newRunnerScript;
    in
      newRunnerDrv;
  };
  
in {
  # Original workflow data
  inherit (workflow) name system pipelines dependencies description;
  
  # Enhanced outputs
  mermaidDiagram = mermaidDiagram;
  runner = runnerDrv;
  
  # Add metadata for workflow execution
  metadata = workflow.metadata or {};
}
