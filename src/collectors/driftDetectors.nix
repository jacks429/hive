{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "driftDetectors";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for drift detectors
  schema = {
    name = {
      description = "Name of the drift detector";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the drift detector";
      type = "string";
      required = false;
    };
    dataSource = {
      description = "Data source configuration";
      type = "set";
      required = false;
    };
    method = {
      description = "Drift detection method";
      type = "string";
      required = false;
    };
    metrics = {
      description = "Metrics to monitor for drift";
      type = "list";
      required = false;
    };
    thresholds = {
      description = "Thresholds for drift detection";
      type = "set";
      required = false;
    };
    system = {
      description = "System for which this drift detector is defined";
      type = "string";
      required = true;
    };
  };

  # Process drift detector configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Drift detector configuration
      dataSource = config.dataSource or {};
      method = config.method or "";
      metrics = config.metrics or [];
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

  # Create a registry of drift detectors
  createRegistry = detectors: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = detectors;
      keyFn = name: item: item.name;
    };

    # Group detectors by method
    detectorsByMethod = collectors.groupBy {
      registry = registry;
      attr = "method";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Drift Detectors Registry

      This registry contains ${toString (l.length (l.attrNames registry))} drift detectors.

      ## Detectors by Method

      ${l.concatStringsSep "\n" (l.mapAttrsToList (method: detectors: ''
        ### Method: ${if method == "" then "default" else method}

        ${l.concatMapStrings (detector: ''
          - **${detector.name}**: ${detector.description} (${toString (l.length detector.metrics)} metrics)
        '') detectors}
      '') detectorsByMethod)}
    '';
  in {
    detectors = registry;
    detectorsByMethod = detectorsByMethod;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}
