{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "adversarialAttacks";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for adversarial attacks
  schema = {
    name = {
      description = "Name of the adversarial attack";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the adversarial attack";
      type = "string";
      required = false;
    };
    target = {
      description = "Target model or system";
      type = "set";
      required = true;
    };
    method = {
      description = "Attack method";
      type = "string";
      required = true;
    };
    parameters = {
      description = "Attack parameters";
      type = "set";
      required = false;
    };
    system = {
      description = "System for which this attack is defined";
      type = "string";
      required = true;
    };
  };

  # Process adversarial attack configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Attack configuration
      target = config.target or {};
      method = config.method or "";
      parameters = config.parameters or {};
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

  # Create a registry of adversarial attacks
  createRegistry = attacks: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = attacks;
      keyFn = name: item: item.name;
    };

    # Group attacks by method
    attacksByMethod = collectors.groupBy {
      registry = registry;
      attr = "method";
    };

    # Generate documentation for the registry
    registryDocs = ''
      # Adversarial Attacks Registry

      This registry contains ${toString (l.length (l.attrNames registry))} adversarial attacks.

      ## Attacks by Method

      ${l.concatStringsSep "\n" (l.mapAttrsToList (method: attacks: ''
        ### Method: ${if method == "" then "default" else method}

        ${l.concatMapStrings (attack: ''
          - **${attack.name}**: ${attack.description}
        '') attacks}
      '') attacksByMethod)}

      ## Attack Details

      ${l.concatMapStrings (name: let attack = registry.${name}; in ''
        ### ${name}

        ${attack.description}

        - **Method**: ${attack.method}
        - **Target**: ${attack.target.name or "Unknown"}

        #### Parameters:

        ${l.concatMapStrings (param: ''
          - **${param}**: ${l.toJSON attack.parameters.${param}}
        '') (l.attrNames attack.parameters)}

      '') (l.attrNames registry)}
    '';
  in {
    attacks = registry;
    attacksByMethod = attacksByMethod;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}
