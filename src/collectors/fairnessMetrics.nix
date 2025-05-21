{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "fairnessMetrics";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for fairness metrics
  schema = {
    name = {
      description = "Name of the fairness metric";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the fairness metric";
      type = "string";
      required = false;
    };
    sensitiveAttributes = {
      description = "Sensitive attributes to measure fairness against";
      type = "list";
      required = true;
    };
    method = {
      description = "Fairness measurement method";
      type = "string";
      required = true;
    };
    thresholds = {
      description = "Fairness thresholds";
      type = "set";
      required = false;
    };
    system = {
      description = "System for which this fairness metric is defined";
      type = "string";
      required = true;
    };
  };

  # Process fairness metric configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Fairness metric configuration
      sensitiveAttributes = config.sensitiveAttributes or [];
      method = config.method or "";
      thresholds = config.thresholds or {};
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

  # Create a registry of fairness metrics
  createRegistry = metrics: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = metrics;
      keyFn = name: item: item.name;
    };

    # Group metrics by method
    metricsByMethod = collectors.groupBy {
      registry = registry;
      attr = "method";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Fairness Metrics Registry

      This registry contains ${toString (l.length (l.attrNames registry))} fairness metrics.

      ## Metrics by Method

      ${l.concatStringsSep "\n" (l.mapAttrsToList (method: metrics: ''
        ### Method: ${if method == "" then "default" else method}

        ${l.concatMapStrings (metric: ''
          - **${metric.name}**: ${metric.description}
        '') metrics}
      '') metricsByMethod)}

      ## Metric Details

      ${l.concatMapStrings (name: let metric = registry.${name}; in ''
        ### ${name}

        ${metric.description}

        - **Method**: ${metric.method}
        - **Sensitive Attributes**: ${l.concatStringsSep ", " metric.sensitiveAttributes}

        #### Thresholds:

        ${l.concatMapStrings (threshold: ''
          - **${threshold}**: ${l.toJSON metric.thresholds.${threshold}}
        '') (l.attrNames metric.thresholds)}

      '') (l.attrNames registry)}
    '';
  in {
    metrics = registry;
    metricsByMethod = metricsByMethod;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}
