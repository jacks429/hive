# Meta-Blocks Research

This directory contains research and prototypes for implementing a meta-block system in the Hive repository. The goal is to unify the patterns used across transformers and collectors, reducing duplication and enforcing structural guarantees.

## Contents

- `07_static_analysis.md`: Comprehensive analysis of the codebase, identifying patterns and duplication
- `lib/codegen.nix`: Minimal implementation of the meta-block API
- `test-transformer.nix`: Example transformer using the meta-block API
- `test-collector.nix`: Example collector using the meta-block API
- `test-codegen.nix`: Unit tests for the meta-block API
- `run-tests.sh`: Script to run the unit tests

## Approach

The approach taken is incremental and non-disruptive:

1. Start with a minimal implementation that focuses on the core functionality
2. Create tests to validate the approach
3. Develop examples to demonstrate usage
4. Gradually refine the API based on feedback
5. Eventually migrate existing transformers and collectors

## Structural Guarantees

The meta-block system aims to enforce six structural guarantees:

1. **Type Safety**: Ensure that fields have the correct types
2. **Composition Constraints**: Validate relationships between blocks
3. **Duplication Prevention**: Detect and prevent duplicate blocks
4. **Early Error Detection**: Catch errors at evaluation time rather than runtime
5. **Safe Parameterization**: Validate required parameters and defaults
6. **Policy Enforcement**: Enforce organizational policies (e.g., output paths)

## Usage

To run the tests:

```bash
./run-tests.sh
```

To use the meta-block API in a new transformer:

```nix
{ nixpkgs, root, inputs }: config:
  (import ./lib/codegen.nix { 
    inherit (nixpkgs) lib; 
    pkgs = nixpkgs.legacyPackages.x86_64-linux; 
  }).mkCodegenBlock {
    name = "my-transformer";
    description = "My transformer";
    blockType = "myType";
    schema = {
      # Define schema here
    };
    processConfig = config: {
      # Process config here
    };
  } config
```

## Next Steps

1. Refine the API based on feedback
2. Add more specialized block types
3. Enhance validation and error reporting
4. Create migration guides for existing transformers
5. Integrate with CI to enforce structural guarantees
