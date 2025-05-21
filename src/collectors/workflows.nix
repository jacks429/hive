{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "workflows";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for workflows
  schema = {
    name = {
      description = "Name of the workflow";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the workflow";
      type = "string";
      required = false;
    };
    pipelines = {
      description = "List of pipelines to execute";
      type = "list";
      required = false;
    };
    dependencies = {
      description = "Dependencies between pipelines (DAG structure)";
      type = "set";
      required = false;
    };
    schedule = {
      description = "Optional scheduling information";
      type = "set";
      required = false;
    };
    resources = {
      description = "Optional resource requirements";
      type = "set";
      required = false;
    };
    notifications = {
      description = "Optional notification configuration";
      type = "set";
      required = false;
    };
    system = {
      description = "System for which this workflow is defined";
      type = "string";
      required = true;
    };
  };

  # Process workflow configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # List of pipelines to execute
      pipelines = config.pipelines or [];

      # Dependencies between pipelines (DAG structure)
      dependencies = config.dependencies or {};

      # Optional scheduling information
      schedule = config.schedule or null;

      # Optional resource requirements
      resources = config.resources or {};

      # Optional notification configuration
      notifications = config.notifications or {};
    };
  in
    # Combine processed parts and validate
    collectors.validateConfig
      (metadata // withDefaults // {
        system = config.system;
      })
      schema;

  # Create the collector using the library function
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;

  # Create a registry of workflows
  createRegistry = workflows: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = workflows;
      keyFn = name: item: item.name;
    };

    # Generate a dependency graph for visualization
    dependencyGraph = l.mapAttrs (name: workflow:
      l.mapAttrs (pipeline: dependencies:
        l.map (dep: { from = dep; to = pipeline; }) dependencies
      ) workflow.dependencies
    ) registry;

    # Generate documentation for the registry
    registryDocs = ''
      # Workflows Registry

      This registry contains ${toString (l.length (l.attrNames registry))} workflows.

      ## Workflows

      ${l.concatMapStrings (name: let workflow = registry.${name}; in ''
        ### ${name}

        ${workflow.description}

        #### Pipelines: ${toString (l.length workflow.pipelines)}

        ${l.concatMapStrings (pipeline: ''
          - ${pipeline}
        '') workflow.pipelines}

        ${if workflow.schedule != null then ''
        #### Schedule: ${workflow.schedule.frequency or "manual"} ${workflow.schedule.time or ""}
        '' else ""}

      '') (l.attrNames registry)}
    '';
  in {
    workflows = registry;
    dependencyGraph = dependencyGraph;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}