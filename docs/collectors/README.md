# Collectors Library

The Collectors Library provides a set of reusable functions for creating and manipulating collectors in the Hive monorepo.

## Overview

The library provides functions for:

- Core collector creation and management
- Configuration handling and validation
- Registry creation and manipulation
- Documentation generation
- Common configuration processors
- Error handling

## Installation

The library is included in the Hive monorepo and can be imported in your Nix files:

```nix
{ inputs, nixpkgs, root }:

let
  inherit (root.lib) collectors;
in
  # Use collectors library functions
  ...
```

## Core Functions

### `mkCollector`

Creates a basic collector with standard structure.

```nix
collectors.mkCollector {
  cellBlock = "myCollector";
  processConfig = config: { /* process config */ };
  filterFn = system: _: config: config.system == system;
} renamer
```

### `withDefaults`

Apply default values to a configuration.

```nix
collectors.withDefaults config {
  name = "";
  description = "";
  # other defaults
}
```

### `validateConfig`

Validate a configuration against a schema.

```nix
collectors.validateConfig config {
  name = {
    description = "Name of the item";
    type = "string";
    required = true;
  };
  # other schema fields
}
```

## Registry Functions

### `mkRegistry`

Create a registry from collector results.

```nix
collectors.mkRegistry {
  collector = myCollector;
  keyFn = name: item: item.name;
}
```

### `groupBy`

Group registry items by a specific attribute.

```nix
collectors.groupBy {
  registry = myRegistry;
  attr = "category";
}
```

### `sortBy`

Sort registry items by a specific attribute.

```nix
collectors.sortBy {
  registry = myRegistry;
  attr = "version";
  order = "desc"; # or "asc"
}
```

## Documentation Generation

### `generateDocs`

Generate documentation for a collector.

```nix
collectors.generateDocs {
  name = "My Collector";
  description = "Collects things";
  schema = {
    # schema definition
  };
}
```

## Common Configuration Processors

### `processMetadata`

Process basic metadata fields.

```nix
collectors.processMetadata config
# Returns { name = "..."; description = "..."; system = "..."; }
```

### `processVersioned`

Process versioned items.

```nix
collectors.processVersioned config
# Returns metadata + { version = "..."; timestamp = "..."; }
```

### `processTagged`

Process items with tags.

```nix
collectors.processTagged config
# Returns metadata + { tags = [...]; }
```

## Error Handling

### `withErrorContext`

Add error context to a function.

```nix
collectors.withErrorContext fn "While processing configuration" config
```

### `safeProcess`

Safely process a configuration with error handling.

```nix
collectors.safeProcess processConfig config
```

## Example Usage

Here's a complete example of a collector using the library:

```nix
{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "myCollector";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;
  
  # Define schema
  schema = {
    name = {
      description = "Name of the item";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the item";
      type = "string";
      required = false;
    };
    system = {
      description = "System for which this item is defined";
      type = "string";
      required = true;
    };
  };
  
  # Process configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;
  in
    # Validate and return
    collectors.validateConfig (metadata // {
      # Add additional fields
      extraField = config.extraField or "default";
      system = config.system;
    }) schema;
  
  # Create the collector
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;
  
  # Create a registry
  createRegistry = items: let
    registry = collectors.mkRegistry {
      collector = items;
      keyFn = name: item: item.name;
    };
  in {
    items = registry;
  };
in {
  collector = walk;
  registry = createRegistry;
}
```
