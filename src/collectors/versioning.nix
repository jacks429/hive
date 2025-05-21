{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "versioning";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for versioning
  schema = {
    name = {
      description = "Name of the versioning rule";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the versioning rule";
      type = "string";
      required = false;
    };
    appliesTo = {
      description = "Target type this versioning rule applies to";
      type = "string";
      required = false;
    };
    pattern = {
      description = "Version pattern to enforce";
      type = "string";
      required = false;
    };
    extractFrom = {
      description = "Version extraction rules";
      type = "set";
      required = false;
    };
    validation = {
      description = "Version validation rules";
      type = "set";
      required = false;
    };
    increment = {
      description = "Version increment rules";
      type = "set";
      required = false;
    };
    format = {
      description = "Version display format";
      type = "string";
      required = false;
    };
    system = {
      description = "System for which this versioning rule is defined";
      type = "string";
      required = true;
    };
  };

  # Process versioning configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Target type this versioning rule applies to
      appliesTo = config.appliesTo or "all"; # "all", "pipelines", "datasets", "models", "microservices"

      # Version pattern to enforce (semver by default)
      pattern = config.pattern or "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$";

      # Version extraction rules
      extractFrom = config.extractFrom or {
        attribute = "version"; # Default attribute to extract version from
        fallback = "0.1.0";    # Default version if not found
      };

      # Version validation rules
      validation = config.validation or {
        required = true;       # Whether version is required
        allowPrerelease = false; # Whether pre-release versions are allowed in production
        allowBuildMetadata = true; # Whether build metadata is allowed
      };

      # Version increment rules
      increment = config.increment or {
        major = "Breaking changes";
        minor = "New features, backwards compatible";
        patch = "Bug fixes, backwards compatible";
      };

      # Version display format
      format = config.format or "v{major}.{minor}.{patch}";
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

  # Create a registry of versioning rules
  createRegistry = rules: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = rules;
      keyFn = name: item: item.name;
    };

    # Group rules by target type
    rulesByTarget = collectors.groupBy {
      registry = registry;
      attr = "appliesTo";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Versioning Rules Registry

      This registry contains ${toString (l.length (l.attrNames registry))} versioning rules.

      ## Rules by Target Type

      ${l.concatStringsSep "\n" (l.mapAttrsToList (target: rules: ''
        ### Target: ${target}

        ${l.concatMapStrings (rule: ''
          - **${rule.name}**: ${rule.description} (Format: ${rule.format})
        '') rules}
      '') rulesByTarget)}

      ## Versioning Patterns

      ${l.concatMapStrings (name: let rule = registry.${name}; in ''
        ### ${name}

        - **Pattern**: \`${rule.pattern}\`
        - **Format**: ${rule.format}
        - **Applies To**: ${rule.appliesTo}

        #### Increment Rules:

        - **Major**: ${rule.increment.major}
        - **Minor**: ${rule.increment.minor}
        - **Patch**: ${rule.increment.patch}

      '') (l.attrNames registry)}
    '';
  in {
    rules = registry;
    rulesByTarget = rulesByTarget;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}