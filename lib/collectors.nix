# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ lib, pkgs }:

let
  l = lib // builtins;
in rec {
  #
  # Core collector functions
  #

  # Create a basic collector with standard structure
  mkCollector = { 
    cellBlock, 
    processConfig ? (x: x),
    filterFn ? (system: _: config: config.system == system)
  }: renamer: let
    inherit (pkgs) walkPaisano;
    
    walk = self:
      walkPaisano self cellBlock (system: cell: [
        (l.mapAttrs (target: config: {
          _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
          imports = [config];
        }))
        (l.mapAttrs (_: processConfig))
        (l.filterAttrs (filterFn system))
      ])
      renamer;
  in
    walk;

  # Apply default values to a configuration
  withDefaults = config: defaults:
    defaults // (removeAttrs config ["__functor"]);

  # Validate a configuration against a schema
  validateConfig = config: schema:
    let
      # Check required fields
      requiredFields = l.filter (field: schema.${field}.required or false) (l.attrNames schema);
      missingFields = l.filter (field: !(l.hasAttr field config)) requiredFields;
      
      # Check field types
      typeErrors = l.mapAttrs (name: value:
        let
          expectedType = schema.${name}.type or null;
          actualType = l.typeOf value;
        in
          if expectedType == null then null
          else if expectedType != actualType then
            "Expected type '${expectedType}' but got '${actualType}'"
          else null
      ) config;
      
      # Filter out null errors
      actualTypeErrors = l.filterAttrs (name: value: value != null) typeErrors;
      
      # Build error message
      errorMsg = 
        if missingFields != [] then
          "Missing required fields: ${l.concatStringsSep ", " missingFields}"
        else if actualTypeErrors != {} then
          "Type errors: ${l.concatStringsSep ", " (l.mapAttrsToList (name: error: "${name}: ${error}") actualTypeErrors)}"
        else null;
    in
      if errorMsg != null then
        throw errorMsg
      else
        config;

  #
  # Registry functions
  #

  # Create a registry from collector results
  mkRegistry = { collector, keyFn ? (name: item: name) }: 
    l.mapAttrs keyFn collector;

  # Group registry items by a specific attribute
  groupBy = { registry, attr }: let
    items = l.attrValues registry;
    keys = l.unique (map (item: item.${attr} or null) 
      (l.filter (item: l.hasAttr attr item) items));
  in
    l.genAttrs keys (key:
      l.filter (item: item.${attr} or null == key) items
    );

  # Sort registry items by a specific attribute
  sortBy = { registry, attr, order ? "asc" }: 
    l.sort (a: b: 
      if order == "asc" then a.${attr} < b.${attr}
      else a.${attr} > b.${attr}
    ) (l.attrValues registry);

  #
  # Documentation generation
  #

  # Generate documentation for a collector
  generateDocs = { name, description, schema ? {} }:
    ''
      # ${name}
      
      ${description}
      
      ${if schema != {} then ''
      ## Schema
      
      ${formatSchema schema}
      '' else ""}
    '';

  # Format schema for documentation
  formatSchema = schema:
    l.concatMapStrings (name:
      let field = schema.${name}; in
      ''
      ### ${name}
      
      ${field.description or ""}
      
      ${if field ? type then "Type: `${field.type}`\n" else ""}
      ${if field ? default then "Default: `${l.toJSON field.default}`\n" else ""}
      ${if field ? required then "Required: ${if field.required then "Yes" else "No"}\n" else ""}
      
      ''
    ) (l.attrNames schema);

  #
  # Common configuration processors
  #

  # Process basic metadata fields
  processMetadata = config: {
    name = config.name or "";
    description = config.description or "";
    system = config.system or null;
  };

  # Process versioned items
  processVersioned = config: {
    version = config.version or "1.0.0";
    timestamp = config.timestamp or "";
  } // (processMetadata config);

  # Process items with tags
  processTagged = config: {
    tags = config.tags or [];
  } // (processMetadata config);

  # Process items with system requirements
  processSystemRequirements = config: {
    resources = config.resources or {};
  } // (processMetadata config);

  #
  # Error handling
  #

  # Add error context to a function
  withErrorContext = fn: context: args:
    builtins.addErrorContext context (fn args);

  # Safely process a configuration with error handling
  safeProcess = fn: config:
    let
      context = "While processing ${config.name or "unnamed"} configuration";
    in
      withErrorContext fn context config;
}
