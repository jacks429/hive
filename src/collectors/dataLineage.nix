{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "dataLineage";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for data lineage
  schema = {
    name = {
      description = "Name of the data lineage definition";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the data lineage";
      type = "string";
      required = false;
    };
    nodes = {
      description = "Node definitions (data sources, transformations, targets)";
      type = "set";
      required = false;
    };
    edges = {
      description = "Edge definitions (transformations between nodes)";
      type = "set";
      required = false;
    };
    system = {
      description = "System for which this data lineage is defined";
      type = "string";
      required = true;
    };
  };

  # Process data lineage configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process nodes with defaults
    processedNodes = l.mapAttrs (name: node: {
      type = node.type or "dataset"; # dataset, table, file, api, etc.
      description = node.description or "";
      schema = node.schema or null;
      owner = node.owner or "";
      tags = node.tags or [];
    }) (config.nodes or {});

    # Process edges with defaults
    processedEdges = l.mapAttrs (source: targets:
      l.map (target: {
        target = target.target;
        transformation = target.transformation or "unknown";
        description = target.description or "";
        pipeline = target.pipeline or null; # Reference to pipeline that performs this transformation
        timestamp = target.timestamp or null; # When this transformation was last run
      }) targets
    ) (config.edges or {});
  in
    # Combine processed parts
    metadata // {
      nodes = processedNodes;
      edges = processedEdges;
      impactAnalysis = config.impactAnalysis or {};
      system = config.system;
    };

  # Create the collector using the library function
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;

  # Create a registry of data lineage definitions
  createRegistry = lineages: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = lineages;
      keyFn = name: item: item.name;
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Data Lineage Registry

      This registry contains ${toString (l.length (l.attrNames registry))} data lineage definitions.

      ## Lineage Definitions

      ${l.concatMapStrings (name: let lineage = registry.${name}; in ''
        ### ${name}

        ${lineage.description}

        #### Nodes: ${toString (l.length (l.attrNames lineage.nodes))}
        #### Edges: ${toString (l.length (l.attrNames lineage.edges))}

      '') (l.attrNames registry)}
    '';
  in {
    lineages = registry;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}