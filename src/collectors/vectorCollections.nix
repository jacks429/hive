{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "vectorCollections";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for vector collections
  schema = {
    name = {
      description = "Name of the vector collection";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the vector collection";
      type = "string";
      required = false;
    };
    store = {
      description = "Reference to a vector store";
      type = "string";
      required = false;
      default = "";
    };
    schema = {
      description = "Schema configuration for the vector collection";
      type = "set";
      required = false;
    };
    system = {
      description = "System for which this collection is defined";
      type = "string";
      required = true;
    };
  };

  # Process vector collection configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process schema with defaults
    schemaWithDefaults = {
      dimensions = config.schema.dimensions or 768;
      metric = config.schema.metric or "cosine";

      # Vector fields
      vectorFields = config.schema.vectorFields or [{
        name = "embedding";
        dimensions = config.schema.dimensions or 768;
      }];

      # Payload/metadata fields
      payloadFields = config.schema.payloadFields or [];

      # Indexing configuration
      indexing = config.schema.indexing or {
        type = "hnsw";
        parameters = {
          m = 16;
          efConstruction = 100;
        };
      };
    };
  in
    # Combine processed parts
    metadata // {
      store = config.store or ""; # Reference to a vectorStore
      schema = schemaWithDefaults;
      system = config.system;
    };

  # Create the collector using the library function
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;

  # Create a registry of vector collections
  createRegistry = collections: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = collections;
      keyFn = name: item: item.name;
    };

    # Group collections by store
    collectionsByStore = collectors.groupBy {
      registry = registry;
      attr = "store";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Vector Collections Registry

      This registry contains ${toString (l.length (l.attrNames registry))} vector collections.

      ## Collections by Store

      ${l.concatStringsSep "\n" (l.mapAttrsToList (store: collections: ''
        ### Store: ${if store == "" then "default" else store}

        ${l.concatMapStrings (collection: ''
          - **${collection.name}**: ${collection.description} (${toString collection.schema.dimensions} dimensions)
        '') collections}
      '') collectionsByStore)}
    '';
  in {
    collections = registry;
    collectionsByStore = collectionsByStore;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}