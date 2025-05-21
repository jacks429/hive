{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "rules";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for rules
  schema = {
    name = {
      description = "Name of the rule set";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the rule set";
      type = "string";
      required = false;
    };
    type = {
      description = "Type of rules (regex, normalization, filtering, tokenization, etc.)";
      type = "string";
      required = false;
    };
    rules = {
      description = "List of rule definitions";
      type = "list";
      required = false;
    };
    system = {
      description = "System for which these rules are defined";
      type = "string";
      required = true;
    };
  };

  # Process rules configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Rule type
      type = config.type or "regex"; # regex, normalization, filtering, tokenization, etc.

      # Rule definition
      rules = config.rules or []; # List of rule definitions

      # Rule format
      format = config.format or "text"; # text, json, yaml

      # Processing options
      caseSensitive = config.caseSensitive or false;

      # Language information (if applicable)
      language = config.language or "en"; # ISO language code

      # Pipeline integration
      appliesTo = config.appliesTo or "text"; # text, tokens, entities, etc.
    };
  in
    # Combine processed parts
    metadata // withDefaults // {
      system = config.system;
    };

  # Create the collector using the library function
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;

  # Create a registry of rules
  createRegistry = rules: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = rules;
      keyFn = name: item: item.name;
    };

    # Group rules by type
    rulesByType = collectors.groupBy {
      registry = registry;
      attr = "type";
    };

    # Group rules by language
    rulesByLanguage = collectors.groupBy {
      registry = registry;
      attr = "language";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Rules Registry

      This registry contains ${toString (l.length (l.attrNames registry))} rule sets.

      ## Rules by Type

      ${l.concatStringsSep "\n" (l.mapAttrsToList (type: rules: ''
        ### Type: ${type}

        ${l.concatMapStrings (rule: ''
          - **${rule.name}**: ${rule.description} (${toString (l.length rule.rules)} rules)
        '') rules}
      '') rulesByType)}

      ## Rules by Language

      ${l.concatStringsSep "\n" (l.mapAttrsToList (language: rules: ''
        ### Language: ${language}

        ${l.concatMapStrings (rule: ''
          - **${rule.name}**: ${rule.description} (${toString (l.length rule.rules)} rules)
        '') rules}
      '') rulesByLanguage)}
    '';
  in {
    rules = registry;
    rulesByType = rulesByType;
    rulesByLanguage = rulesByLanguage;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}