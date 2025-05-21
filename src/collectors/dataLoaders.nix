{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "dataLoaders";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for data loaders
  schema = {
    name = {
      description = "Name of the data loader";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the data loader";
      type = "string";
      required = false;
    };
    source = {
      description = "Source configuration";
      type = "set";
      required = true;
    };
    destination = {
      description = "Destination configuration";
      type = "set";
      required = true;
    };
    transform = {
      description = "Transformation to apply during loading";
      type = "set";
      required = false;
    };
    schedule = {
      description = "Schedule information";
      type = "set";
      required = false;
    };
    dependencies = {
      description = "Dependencies";
      type = "list";
      required = false;
    };
    system = {
      description = "System for which this data loader is defined";
      type = "string";
      required = true;
    };
  };

  # Process data loader configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Source configuration
      source = {
        type = config.source.type or "file"; # file, s3, http, database, api
        location = config.source.location or "";
        credentials = config.source.credentials or null;
        options = config.source.options or {};
      };

      # Destination configuration (typically references a dataset)
      destination = {
        dataset = config.destination.dataset or "";
        format = config.destination.format or "raw";
        options = config.destination.options or {};
      };

      # Transformation to apply during loading (minimal)
      transform = config.transform or null;

      # Schedule information
      schedule = config.schedule or null;

      # Dependencies
      dependencies = config.dependencies or [];
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

  # Create a registry of data loaders
  createRegistry = loaders: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = loaders;
      keyFn = name: item: item.name;
    };

    # Group loaders by source type
    loadersBySourceType = collectors.groupBy {
      registry = registry;
      attr = "source.type";
    };

    # Group loaders by destination dataset
    loadersByDestination = collectors.groupBy {
      registry = registry;
      attr = "destination.dataset";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Data Loaders Registry

      This registry contains ${toString (l.length (l.attrNames registry))} data loaders.

      ## Loaders by Source Type

      ${l.concatStringsSep "\n" (l.mapAttrsToList (sourceType: loaders: ''
        ### Source Type: ${sourceType}

        ${l.concatMapStrings (loader: ''
          - **${loader.name}**: ${loader.description} (→ ${loader.destination.dataset})
        '') loaders}
      '') loadersBySourceType)}

      ## Loaders by Destination Dataset

      ${l.concatStringsSep "\n" (l.mapAttrsToList (dataset: loaders: ''
        ### Dataset: ${dataset}

        ${l.concatMapStrings (loader: ''
          - **${loader.name}**: ${loader.description} (from ${loader.source.type})
        '') loaders}
      '') loadersByDestination)}
    '';
  in {
    loaders = registry;
    loadersBySourceType = loadersBySourceType;
    loadersByDestination = loadersByDestination;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}