# Transformers Library

The Transformers Library provides a set of reusable functions for creating and manipulating transformers in the Hive monorepo.

## Overview

The library provides functions for:

- Configuration handling
- CLI argument parsing
- Documentation generation
- Derivation creation
- Block discovery and enumeration
- Error handling
- Result marshaling

## Installation

The library is included in the Hive monorepo and can be imported in your Nix files:

```nix
{ nixpkgs, root, inputs }:
config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Use the library...
in
  # ...
```

## API Reference

### Configuration Handling

#### `withDefaults`

Apply default values to a configuration.

```nix
withDefaults :: config -> defaults -> config
```

Example:

```nix
let
  config = { a = 1; c = 3; };
  defaults = { a = 0; b = 2; };
  result = transformers.withDefaults config defaults;
  # result = { a = 1; b = 2; c = 3; }
in
  # ...
```

#### `validateConfig`

Validate a configuration against a schema.

```nix
validateConfig :: config -> schema -> config
```

Example:

```nix
let
  schema = {
    a = { type = "int"; required = true; };
    b = { type = "string"; required = false; };
  };
  config = { a = 1; b = "test"; };
  result = transformers.validateConfig config schema;
in
  # ...
```

### CLI Argument Parsing

#### `withArgs`

Generate a script with argument parsing.

```nix
withArgs :: { name, description, args ? [], flags ? [] } -> script -> script
```

Example:

```nix
let
  script = transformers.withArgs {
    name = "greet";
    description = "Greet someone";
    args = [
      { name = "name"; description = "Name to greet"; required = true; position = 0; }
    ];
  } ''
    echo "Hello, $name!"
  '';
in
  # ...
```

#### `parseArgs`

Parse arguments from a script.

```nix
parseArgs :: { args, flags ? [] } -> script
```

Example:

```nix
let
  argParsingCode = transformers.parseArgs {
    args = [
      { name = "name"; description = "Name to greet"; required = true; position = 0; }
    ];
  };
in
  # ...
```

### Documentation Generation

#### `generateDocs`

Generate documentation for a transformer.

```nix
generateDocs :: { name, description, usage, examples, params ? {} } -> string
```

Example:

```nix
let
  docs = transformers.generateDocs {
    name = "test-tool";
    description = "A test tool";
    usage = "test-tool [options]";
    examples = "test-tool --example";
    params = {
      example = {
        description = "An example parameter";
        type = "string";
        default = "default";
        required = false;
      };
    };
  };
in
  # ...
```

#### `formatParams`

Format parameters for documentation.

```nix
formatParams :: params -> string
```

Example:

```nix
let
  params = {
    example = {
      description = "An example parameter";
      type = "string";
      default = "default";
      required = false;
    };
  };
  formattedParams = transformers.formatParams params;
in
  # ...
```

### Derivation Creation

#### `mkScript`

Create a script derivation.

```nix
mkScript :: { name, description ? "", script } -> derivation
```

Example:

```nix
let
  script = transformers.mkScript {
    name = "test-script";
    description = "A test script";
    script = "echo Hello, world!";
  };
in
  # ...
```

#### `mkDocs`

Create a documentation derivation.

```nix
mkDocs :: { name, content } -> derivation
```

Example:

```nix
let
  docs = transformers.mkDocs {
    name = "test-docs";
    content = "# Test Documentation";
  };
in
  # ...
```

#### `mkPackage`

Create a package derivation that bundles multiple derivations.

```nix
mkPackage :: { name, paths } -> derivation
```

Example:

```nix
let
  package = transformers.mkPackage {
    name = "test-package";
    paths = [ script docs ];
  };
in
  # ...
```

### Block Discovery and Enumeration

#### `mapBlocks`

Map a function over all blocks of a certain type.

```nix
mapBlocks :: { cells, blockType, fn } -> attrset
```

Example:

```nix
let
  result = transformers.mapBlocks {
    cells = inputs.cells;
    blockType = "transformers";
    fn = { cellName, blockName, block }: {
      name = "${cellName}-${blockName}";
      value = block;
    };
  };
in
  # ...
```

#### `filterBlocks`

Filter blocks based on a predicate.

```nix
filterBlocks :: { blocks, predicate } -> attrset
```

Example:

```nix
let
  result = transformers.filterBlocks {
    blocks = inputs.cells.example.transformers;
    predicate = block: block.system == "x86_64-linux";
  };
in
  # ...
```

### Error Handling

#### `withErrorHandling`

Add error handling to a script.

```nix
withErrorHandling :: script -> script
```

Example:

```nix
let
  script = transformers.withErrorHandling ''
    echo "Doing something risky..."
    rm -rf /tmp/test
  '';
in
  # ...
```

### Result Marshaling

#### `toJSON`

Convert a value to JSON.

```nix
toJSON :: value -> string
```

Example:

```nix
let
  json = transformers.toJSON { a = 1; b = "test"; };
in
  # ...
```

#### `fromJSON`

Parse JSON into a value.

```nix
fromJSON :: json -> value
```

Example:

```nix
let
  value = transformers.fromJSON ''{"a": 1, "b": "test"}'';
in
  # ...
```

### Helpers for Specific Transformer Types

#### `mkModelTransformer`

Create a model transformer.

```nix
mkModelTransformer :: { name, description, modelUri, framework, params ? {}, service ? null } -> attrset
```

Example:

```nix
let
  model = transformers.mkModelTransformer {
    name = "test-model";
    description = "A test model";
    modelUri = "test-uri";
    framework = "test-framework";
    params = { param1 = "value1"; };
    service = { enable = true; };
  };
in
  # ...
```

## Examples

### Creating a Simple Transformer

```nix
{ nixpkgs, root, inputs }:
config: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${config.system};
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Extract configuration
  tool = {
    inherit (config) name description;
    options = config.options or {};
  };
  
  # Create runner script
  runnerScript = transformers.withArgs {
    name = tool.name;
    description = tool.description;
    args = [
      { name = "input"; description = "Input file"; required = true; position = 0; }
      { name = "output"; description = "Output file"; required = false; position = 1; }
    ];
    flags = [
      { name = "verbose"; description = "Enable verbose output"; type = "boolean"; }
    ];
  } ''
    echo "Running ${tool.name}..."
    
    if [ -n "$verbose" ]; then
      echo "Verbose mode enabled"
    fi
    
    echo "Processing $input..."
    
    if [ -n "$output" ]; then
      echo "Result written to $output"
    else
      echo "Result:"
      echo "..."
    fi
  '';
  
  # Generate documentation
  docs = transformers.generateDocs {
    name = tool.name;
    description = tool.description;
    usage = "${tool.name} <input> [output] [--verbose]";
    examples = "${tool.name} input.txt output.txt --verbose";
    params = {
      input = {
        description = "Input file to process";
        type = "string";
        required = true;
      };
      output = {
        description = "Output file to write results to";
        type = "string";
        required = false;
      };
      verbose = {
        description = "Enable verbose output";
        type = "boolean";
        default = false;
      };
    };
  };
  
  # Create derivations
  runnerDrv = transformers.mkScript {
    name = tool.name;
    description = tool.description;
    script = runnerScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = tool.name;
    content = docs;
  };
  
  packageDrv = transformers.mkPackage {
    name = tool.name;
    paths = [ runnerDrv docsDrv ];
  };
  
in {
  # Original configuration
  inherit (tool) name description options;
  
  # Derivations
  runner = runnerDrv;
  docs = docsDrv;
  package = packageDrv;
}
```

## Contributing

To contribute to the Transformers Library:

1. Make your changes to `lib/transformers.nix`
2. Add tests to `checks/transformers-tests.nix`
3. Run the tests with `nix-build -A checks.transformers-tests`
4. Update the documentation in `docs/transformers/README.md`
5. Submit a pull request
