{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all workflows
  workflows = root.collectors.workflowsConfigurations renamer;
  
  # Create a registry of workflow definitions, keyed by name
  workflowsRegistry = l.mapAttrs (name: workflow: {
    inherit (workflow) name system pipelines dependencies description mermaidDiagram;
    metadata = workflow.metadata or {};
  }) workflows;
  
  # Generate combined documentation for all workflows
  allWorkflowsDocs = let
    workflowsList = l.mapAttrsToList (name: workflow: ''
      ## Workflow: ${name}
      
      ${workflow.description}
      
      ### Pipelines
      ${l.concatMapStrings (pipeline: 
        let deps = workflow.dependencies.${pipeline}; in
        "- ${pipeline} (depends on: ${if deps == [] then "none" else l.concatStringsSep ", " deps})\n"
      ) workflow.pipelines}
      
      ### Dependency Graph
      
      ```mermaid
      ${workflow.mermaidDiagram}
      ```
      
      ${l.optionalString (workflow ? metadata) ''
      ### Metadata
      ${l.concatMapStrings (key: "- ${key}: ${workflow.metadata.${key}}\n") 
        (l.attrNames workflow.metadata)}
      ''}
      
      ---
    '') workflowsRegistry;
  in ''
    # Workflows Registry
    
    This document contains information about all available workflows.
    
    ${l.concatStringsSep "\n" workflowsList}
  '';
  
  # Generate a combined dependency graph for all workflows
  combinedMermaidDiagram = let
    allDiagrams = l.mapAttrsToList (name: workflow: 
      l.replaceStrings ["flowchart TD"] ["subgraph ${name}"] workflow.mermaidDiagram
      + "\nend\n"
    ) workflows;
  in ''
    flowchart TD
    ${l.concatStringsSep "\n" allDiagrams}
  '';
  
in {
  registry = workflowsRegistry;
  documentation = allWorkflowsDocs;
  combinedDiagram = combinedMermaidDiagram;
}