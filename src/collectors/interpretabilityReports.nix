{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "interpretabilityReports";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for interpretability reports
  schema = {
    name = {
      description = "Name of the interpretability report";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the interpretability report";
      type = "string";
      required = false;
    };
    model = {
      description = "Model to interpret";
      type = "set";
      required = true;
    };
    methods = {
      description = "Interpretability methods to use";
      type = "list";
      required = true;
    };
    datasets = {
      description = "Datasets to use for interpretation";
      type = "list";
      required = false;
    };
    system = {
      description = "System for which this report is defined";
      type = "string";
      required = true;
    };
  };

  # Process interpretability report configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Interpretability report configuration
      model = config.model or {};
      methods = config.methods or [];
      datasets = config.datasets or [];
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

  # Create a registry of interpretability reports
  createRegistry = reports: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = reports;
      keyFn = name: item: item.name;
    };

    # Group reports by model
    reportsByModel = collectors.groupBy {
      registry = registry;
      attr = "model.name";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Interpretability Reports Registry

      This registry contains ${toString (l.length (l.attrNames registry))} interpretability reports.

      ## Reports by Model

      ${l.concatStringsSep "\n" (l.mapAttrsToList (modelName: reports: ''
        ### Model: ${modelName}

        ${l.concatMapStrings (report: ''
          - **${report.name}**: ${report.description}
        '') reports}
      '') reportsByModel)}

      ## Report Details

      ${l.concatMapStrings (name: let report = registry.${name}; in ''
        ### ${name}

        ${report.description}

        - **Model**: ${report.model.name or "Unknown"}
        - **Methods**: ${l.concatStringsSep ", " report.methods}
        - **Datasets**: ${l.concatStringsSep ", " report.datasets}

      '') (l.attrNames registry)}
    '';
  in {
    reports = registry;
    reportsByModel = reportsByModel;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}
