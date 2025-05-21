{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all evaluation workflows
  evaluationWorkflows = root.collectors.evaluationWorkflows renamer;
  
  # Create a registry of evaluation workflow definitions, keyed by name
  evaluationWorkflowsRegistry = l.mapAttrs (name: workflow: {
    inherit (workflow) name system dataLoader model metrics;
    description = workflow.description or "";
    mermaidDiagram = workflow.mermaidDiagram or "";
  }) evaluationWorkflows;
  
  # Generate combined documentation for all evaluation workflows
  allEvaluationWorkflowsDocs = let
    workflowsList = l.mapAttrsToList (name: workflow: ''
      ## Evaluation Workflow: ${name}
      
      ${workflow.description}
      
      ### Components
      - Data Loader: ${workflow.dataLoader}
      - Model/Pipeline: ${workflow.model}
      - Evaluation Metrics: ${l.concatStringsSep ", " workflow.metrics}
      
      ### Dependency Graph
      
      ```mermaid
      ${workflow.mermaidDiagram}
      ```
      
      ---
    '') evaluationWorkflowsRegistry;
  in ''
    # Evaluation Workflows Registry
    
    This document contains information about all available evaluation workflows.
    
    ${l.concatStringsSep "\n" workflowsList}
  '';
  
  # Generate a combined dependency graph for all evaluation workflows
  combinedMermaidDiagram = let
    allDiagrams = l.mapAttrsToList (name: workflow: 
      l.replaceStrings ["flowchart TD"] ["subgraph ${name}"] workflow.mermaidDiagram
      + "\nend\n"
    ) evaluationWorkflows;
  in ''
    flowchart TD
    ${l.concatStringsSep "\n" allDiagrams}
  '';
  
in {
  registry = evaluationWorkflowsRegistry;
  documentation = allEvaluationWorkflowsDocs;
  combinedDiagram = combinedMermaidDiagram;
}