{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "lexicons";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for lexicons
  schema = {
    name = {
      description = "Name of the lexicon";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the lexicon";
      type = "string";
      required = false;
    };
    type = {
      description = "Lexicon type (stopwords, gazetteer, sentiment, etc.)";
      type = "string";
      required = false;
    };
    source = {
      description = "Path to source file or inline content";
      type = "string";
      required = false;
    };
    format = {
      description = "Format of the lexicon (text, json, csv, tsv)";
      type = "string";
      required = false;
    };
    language = {
      description = "ISO language code";
      type = "string";
      required = false;
    };
    system = {
      description = "System for which this lexicon is defined";
      type = "string";
      required = true;
    };
  };

  # Process lexicon configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Lexicon type
      type = config.type or "generic"; # stopwords, gazetteer, sentiment, etc.

      # Source configuration
      source = config.source or null; # Path to source file or inline content
      format = config.format or "text"; # text, json, csv, tsv

      # Processing options
      caseSensitive = config.caseSensitive or false;
      normalize = config.normalize or true; # Apply normalization (lowercase, etc.)
      stemming = config.stemming or false; # Apply stemming
      lemmatization = config.lemmatization or false; # Apply lemmatization

      # Language information
      language = config.language or "en"; # ISO language code

      # Output configuration
      outputFormat = config.outputFormat or "text"; # text, json, binary, trie
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

  # Create a registry of lexicons
  createRegistry = lexicons: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = lexicons;
      keyFn = name: item: item.name;
    };

    # Group lexicons by type
    lexiconsByType = collectors.groupBy {
      registry = registry;
      attr = "type";
    };

    # Group lexicons by language
    lexiconsByLanguage = collectors.groupBy {
      registry = registry;
      attr = "language";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Lexicons Registry

      This registry contains ${toString (l.length (l.attrNames registry))} lexicons.

      ## Lexicons by Type

      ${l.concatStringsSep "\n" (l.mapAttrsToList (type: lexicons: ''
        ### Type: ${type}

        ${l.concatMapStrings (lexicon: ''
          - **${lexicon.name}**: ${lexicon.description} (${lexicon.language})
        '') lexicons}
      '') lexiconsByType)}

      ## Lexicons by Language

      ${l.concatStringsSep "\n" (l.mapAttrsToList (language: lexicons: ''
        ### Language: ${language}

        ${l.concatMapStrings (lexicon: ''
          - **${lexicon.name}**: ${lexicon.description} (${lexicon.type})
        '') lexicons}
      '') lexiconsByLanguage)}
    '';
  in {
    lexicons = registry;
    lexiconsByType = lexiconsByType;
    lexiconsByLanguage = lexiconsByLanguage;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}