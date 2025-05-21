{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all pipeline configurations
  pipelineConfigurations = root.collectors.pipelinesConfigurations renamer;
  
  # Create a registry of pipeline configuration definitions, keyed by name
  pipelineConfigurationsRegistry = l.mapAttrs (name: attrs: {
    description = attrs.description or "";
    inputs = attrs.inputs or [];        # e.g. [ "./data/raw.csv" ]
    outputs = attrs.outputs or [];      # e.g. [ "./data/out.json" ]
    services = attrs.services or [];    # e.g. [ "qdrant", "elasticsearch" ]
    resources = attrs.resources or {};  # e.g. { cpu="1"; memory="2Gi"; }
    
    # Steps with dependency information
    steps = l.map (step: {
      name = step.name;
      command = step.command;
      depends = step.depends or [];     # for DAG edges
    }) attrs.steps;
    
    # System information
    system = attrs.system;
    
    # Metadata
    metadata = attrs.metadata or {};
    
    # Runner reference
    runner = attrs.runner;
    
    # Mermaid diagram
    mermaidDiagram = attrs.mermaidDiagram;
  }) pipelineConfigurations;
  
  # Generate combined documentation for all pipeline configurations
  allPipelineConfigurationsDocs = let
    pipelineConfigurationsList = l.mapAttrsToList (name: pipelineConfig: ''
      ## Pipeline Configuration: ${name}
      
      ${pipelineConfig.description}
      
      **System:** ${pipelineConfig.system}
      
      ### Inputs
      ${if pipelineConfig.inputs == [] then "None" else 
        l.concatMapStrings (input: "- ${input}\n") pipelineConfig.inputs}
      
      ### Outputs
      ${if pipelineConfig.outputs == [] then "None" else 
        l.concatMapStrings (output: "- ${output}\n") pipelineConfig.outputs}
      
      ### Services
      ${if pipelineConfig.services == [] then "None" else 
        l.concatMapStrings (service: "- ${service}\n") pipelineConfig.services}
      
      ### Resources
      ${if pipelineConfig.resources == {} then "None" else 
        l.concatMapStrings (name: "- ${name}: ${pipelineConfig.resources.${name}}\n") 
          (l.attrNames pipelineConfig.resources)}
      
      ### Steps
      ${l.concatMapStrings (step: ''
        #### ${step.name}
        
        Dependencies: ${if step.depends == [] then "None" else l.concatStringsSep ", " step.depends}
        
      '') pipelineConfig.steps}
      
      ### Dependency Graph
      
      ```mermaid
      ${pipelineConfig.mermaidDiagram}
      ```
      
      ---
    '') pipelineConfigurationsRegistry;
  in ''
    # Pipeline Configurations Registry
    
    This document contains information about all available pipeline configurations.
    
    ${l.concatStringsSep "\n" pipelineConfigurationsList}
  '';
  
  # Generate a combined dependency graph for all pipeline configurations
  combinedMermaidDiagram = let
    allDiagrams = l.mapAttrsToList (name: pipelineConfig: 
      l.replaceStrings ["flowchart TD"] ["subgraph ${name}"] pipelineConfig.mermaidDiagram
      + "\nend\n"
    ) pipelineConfigurations;
  in ''
    flowchart TD
    ${l.concatStringsSep "\n" allDiagrams}
  '';
  
  # Generate the uber pipeline configuration
  uberPipelineConfiguration = 
    pipelineConfigurations.${l.head (l.attrNames pipelineConfigurations)}.generateUberPipelineConfiguration 
    pipelineConfigurations;
  
in {
  registry = pipelineConfigurationsRegistry;
  documentation = allPipelineConfigurationsDocs;
  combinedDiagram = combinedMermaidDiagram;
  uberPipelineConfiguration = uberPipelineConfiguration;
}