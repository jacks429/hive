# Static Analysis of Hive Repository

## Baseline Metrics

### Transformer Patterns

After analyzing the codebase, we've identified several common patterns across transformers:

1. **Configuration Processing**:
   - Almost all transformers follow a pattern of accepting a config object and returning a processed version
   - Common operations include extracting fields, applying defaults, and computing derived values
   - Example: `vectorCollections.nix` extracts collection definition and adds derivations

2. **Schema Validation**:
   - Many transformers implicitly validate configurations but don't use a consistent approach
   - The `lib/transformers.nix` provides a `validateConfig` function that's underutilized
   - Opportunity to enforce schema validation consistently

3. **Documentation Generation**:
   - Most transformers generate documentation in Markdown format
   - Common pattern of including name, description, configuration details, and examples
   - The `lib/transformers.nix` provides a `generateDocs` function that could be used more consistently

4. **CLI Argument Parsing**:
   - Several transformers generate scripts with argument parsing
   - The `lib/transformers.nix` provides `withArgs` and `parseArgs` functions
   - Opportunity to standardize CLI interfaces

5. **Error Handling**:
   - Inconsistent error handling across transformers
   - Some use try/catch in generated scripts, others don't handle errors at all
   - The `lib/transformers.nix` provides a `withErrorHandling` function that's underutilized

### Collector Patterns

1. **Registry Creation**:
   - Most collectors follow a pattern of creating a collector and a registry
   - Common operations include grouping, filtering, and transforming collected items
   - Example: `vectorCollections.nix` creates a registry and groups collections by store

2. **Configuration Processing**:
   - Similar to transformers, collectors process configurations with defaults and validation
   - The `lib/collectors.nix` provides `withDefaults` and `validateConfig` functions

3. **Documentation Generation**:
   - Many collectors generate documentation for the registry
   - Common pattern of summarizing collected items and providing navigation

### Duplication Analysis

Significant duplication exists in:

1. **Configuration Processing Logic**: 
   - Similar validation and default application code appears in multiple transformers
   - Opportunity to extract into a shared `mkConfigProcessor` function

2. **Documentation Generation**:
   - Similar Markdown generation logic across transformers and collectors
   - Opportunity to create a unified documentation system

3. **CLI Interfaces**:
   - Similar argument parsing and help text generation
   - Opportunity to standardize with a `mkCLI` function

4. **Error Handling**:
   - Similar try/catch patterns and error reporting
   - Opportunity to enforce consistent error handling

5. **Registry Creation**:
   - Similar collection and grouping logic across collectors
   - Opportunity to enhance the existing `mkRegistry` function

## Meta-Block API Proposal

Based on the analysis, we propose a unified meta-block API in `lib/codegen.nix`:

```nix
{ lib, pkgs }:

let
  l = lib // builtins;
  transformers = import ./transformers.nix { inherit lib pkgs; };
  collectors = import ./collectors.nix { inherit lib pkgs; };
in rec {
  # Core meta-block factory
  mkCodegenBlock = {
    # Block identification
    name,
    description,
    blockType,
    
    # Schema definition
    schema ? {},
    
    # Processing functions
    processConfig ? (x: x),
    validateSchema ? true,
    
    # Output generation
    generateDocs ? true,
    generateCLI ? false,
    cliOptions ? {},
    
    # Error handling
    withErrorContext ? true,
    
    # Additional options
    extraOptions ? {}
  }: config: let
    # Validate schema if enabled
    validatedConfig = 
      if validateSchema && schema != {} 
      then transformers.validateConfig config schema
      else config;
    
    # Process configuration with error context if enabled
    processedConfig = 
      if withErrorContext
      then collectors.safeProcess processConfig validatedConfig
      else processConfig validatedConfig;
    
    # Generate documentation if enabled
    docs = 
      if generateDocs
      then transformers.generateDocs {
        name = processedConfig.name or name;
        description = processedConfig.description or description;
        params = schema;
      }
      else null;
    
    # Generate CLI if enabled
    cli = 
      if generateCLI
      then transformers.withArgs (cliOptions // {
        name = processedConfig.name or name;
        description = processedConfig.description or description;
      }) (extraOptions.cliScript or "echo 'Not implemented'")
      else null;
    
    # Combine results
    result = processedConfig // {
      _type = blockType;
      _meta = {
        inherit name description blockType schema;
      };
      documentation = docs;
    } // (if cli != null then { cli = cli; } else {});
  in
    result;

  # Specialized meta-blocks for common patterns
  
  # Meta-block for schema-based code generation
  mkSchemaBlock = {
    name,
    description,
    blockType,
    schemaFormat ? "json-schema", # or "protobuf", "nickel", etc.
    outputFormats ? ["json", "markdown"],
    extraOptions ? {}
  }: let
    # Schema-specific processing based on format
    processConfig = config: let
      # Common processing
      baseConfig = {
        inherit (config) name description;
        schema = config.schema or {};
        system = config.system or null;
      };
      
      # Format-specific processing
      formatConfig = 
        if schemaFormat == "json-schema" then {
          # JSON Schema specific processing
          jsonSchema = pkgs.writeTextFile {
            name = "${config.name}-schema.json";
            text = builtins.toJSON (config.schema or {});
          };
        }
        else if schemaFormat == "protobuf" then {
          # Protobuf specific processing
          protoFile = pkgs.writeTextFile {
            name = "${config.name}.proto";
            text = config.schema or "";
          };
        }
        else if schemaFormat == "nickel" then {
          # Nickel specific processing
          nickelFile = pkgs.writeTextFile {
            name = "${config.name}.ncl";
            text = config.schema or "";
          };
        }
        else {};
      
      # Output format generation
      outputs = l.genAttrs outputFormats (format:
        if format == "json" then
          pkgs.writeTextFile {
            name = "${config.name}.json";
            text = builtins.toJSON baseConfig;
          }
        else if format == "markdown" then
          pkgs.writeTextFile {
            name = "${config.name}.md";
            text = ''
              # ${config.name}
              
              ${config.description or ""}
              
              ## Schema
              
              ```${if schemaFormat == "json-schema" then "json" else schemaFormat}
              ${builtins.toJSON (config.schema or {})}
              ```
            '';
          }
        else null
      );
    in
      baseConfig // formatConfig // { inherit outputs; };
  in
    mkCodegenBlock {
      inherit name description blockType;
      inherit processConfig;
      inherit extraOptions;
    };

  # Meta-block for vector operations
  mkVectorBlock = {
    name,
    description,
    blockType,
    extraOptions ? {}
  }:
    mkCodegenBlock {
      inherit name description blockType;
      schema = {
        name = {
          description = "Name of the vector resource";
          type = "string";
          required = true;
        };
        description = {
          description = "Description of the vector resource";
          type = "string";
          required = false;
        };
        dimensions = {
          description = "Number of dimensions in the vector";
          type = "int";
          required = false;
          default = 768;
        };
        metric = {
          description = "Distance metric to use";
          type = "string";
          required = false;
          default = "cosine";
        };
        system = {
          description = "System for which this resource is defined";
          type = "string";
          required = true;
        };
      };
      processConfig = config: let
        baseConfig = {
          inherit (config) name description system;
          dimensions = config.dimensions or 768;
          metric = config.metric or "cosine";
        };
      in
        baseConfig;
      inherit extraOptions;
    };

  # Meta-block for data processing pipelines
  mkPipelineBlock = {
    name,
    description,
    blockType,
    extraOptions ? {}
  }:
    mkCodegenBlock {
      inherit name description blockType;
      schema = {
        name = {
          description = "Name of the pipeline";
          type = "string";
          required = true;
        };
        description = {
          description = "Description of the pipeline";
          type = "string";
          required = false;
        };
        steps = {
          description = "Pipeline processing steps";
          type = "list";
          required = true;
        };
        system = {
          description = "System for which this pipeline is defined";
          type = "string";
          required = true;
        };
      };
      processConfig = config: let
        baseConfig = {
          inherit (config) name description steps system;
        };
      in
        baseConfig;
      inherit extraOptions;
    };

  # Collector factory for meta-blocks
  mkMetaBlockCollector = {
    cellBlock,
    blockType,
    processConfig ? (x: x),
    filterFn ? (system: _: config: config.system == system)
  }: let
    # Create the basic collector
    collector = collectors.mkCollector {
      inherit cellBlock processConfig filterFn;
    };
    
    # Create a registry function
    registry = items: let
      # Basic registry
      basicRegistry = collectors.mkRegistry {
        collector = items;
        keyFn = name: item: item.name;
      };
      
      # Group by type if available
      groupedRegistry = 
        if l.all (item: item ? _type) (l.attrValues basicRegistry)
        then collectors.groupBy {
          registry = basicRegistry;
          attr = "_type";
        }
        else {};
      
      # Generate documentation
      docs = ''
        # ${blockType} Registry
        
        This registry contains ${toString (l.length (l.attrNames basicRegistry))} items.
        
        ${if groupedRegistry != {} then ''
          ## Items by Type
          
          ${l.concatStringsSep "\n" (l.mapAttrsToList (type: items: ''
            ### Type: ${type}
            
            ${l.concatMapStrings (item: ''
              - **${item.name}**: ${item.description or ""}
            '') items}
          '') groupedRegistry)}
        '' else ""}
      '';
    in {
      items = basicRegistry;
      groupedItems = groupedRegistry;
      documentation = docs;
    };
  in {
    collector = collector;
    registry = registry;
  };
}
```

## Refactored Transformer Examples

### JSON-Schema Transformer

```nix
{ nixpkgs, root, inputs }: config:
  root.lib.codegen.mkSchemaBlock {
    name = "json-schema";
    description = "JSON Schema transformer";
    blockType = "jsonSchema";
    schemaFormat = "json-schema";
    outputFormats = ["json", "markdown", "typescript"];
    extraOptions = {
      # TypeScript generation options
      tsOptions = {
        interfacePrefix = "I";
        generateEnums = true;
      };
    };
  } config
```

### Protobuf Transformer

```nix
{ nixpkgs, root, inputs }: config:
  root.lib.codegen.mkSchemaBlock {
    name = "protobuf";
    description = "Protocol Buffers transformer";
    blockType = "protobuf";
    schemaFormat = "protobuf";
    outputFormats = ["json", "markdown", "go", "python", "typescript"];
    extraOptions = {
      # Language-specific options
      languageOptions = {
        go = {
          package = "main";
          goModule = "example.com/proto";
        };
        python = {
          package = "proto";
        };
      };
    };
  } config
```

### Vector Collections Transformer

```nix
{ nixpkgs, root, inputs }: config:
  root.lib.codegen.mkVectorBlock {
    name = "vector-collections";
    description = "Vector collections transformer";
    blockType = "vectorCollections";
    extraOptions = {
      # Vector-specific options
      vectorOptions = {
        generateInitScript = true;
        supportedStores = ["qdrant", "milvus", "pinecone", "local"];
      };
    };
  } config
```

## Collector Validation & CI Checks

To ensure the meta-block system maintains structural guarantees, we propose the following validation and CI checks:

1. **Type Safety Validation**:
   ```nix
   validateTypes = block: let
     schema = block._meta.schema or {};
     errors = lib.mapAttrsToList (name: field:
       if block ? ${name} && field ? type && lib.typeOf block.${name} != field.type
       then "Field '${name}' has type '${lib.typeOf block.${name}}' but expected '${field.type}'"
       else null
     ) schema;
     realErrors = lib.filter (e: e != null) errors;
   in
     if realErrors != [] then throw (lib.concatStringsSep "\n" realErrors) else block;
   ```

2. **Composition Constraint Validation**:
   ```nix
   validateComposition = blocks: let
     blocksByType = lib.groupBy (block: block._type or "unknown") blocks;
     validateTypeConstraints = type: typeBlocks:
       if type == "pipeline" then
         # Check that all referenced steps exist
         let
           allStepRefs = lib.concatMap (block: block.steps) typeBlocks;
           missingSteps = lib.filter (step: 
             !(lib.any (block: block.name == step) blocks)
           ) allStepRefs;
         in
           if missingSteps != [] 
           then throw "Missing referenced steps: ${lib.concatStringsSep ", " missingSteps}"
           else typeBlocks
       else typeBlocks;
   in
     lib.mapAttrsToList validateTypeConstraints blocksByType;
   ```

3. **Duplication Detection**:
   ```nix
   detectDuplication = blocks: let
     blocksByName = lib.groupBy (block: block.name) blocks;
     duplicates = lib.filterAttrs (name: blocks: lib.length blocks > 1) blocksByName;
   in
     if duplicates != {} 
     then throw "Duplicate blocks found: ${lib.concatStringsSep ", " (lib.attrNames duplicates)}"
     else blocks;
   ```

4. **Early Error Detection**:
   ```nix
   validateEarly = { blocks, schema }: let
     # Validate all blocks against their schemas at evaluation time
     validatedBlocks = map (block: 
       if block ? _meta && block._meta ? schema
       then validateTypes block
       else block
     ) blocks;
   in
     validatedBlocks;
   ```

5. **Safe Parameterization**:
   ```nix
   validateParameters = block: let
     # Check that all required parameters are provided
     schema = block._meta.schema or {};
     requiredFields = lib.filter (name: schema.${name}.required or false) (lib.attrNames schema);
     missingFields = lib.filter (name: !(block ? ${name})) requiredFields;
   in
     if missingFields != [] 
     then throw "Missing required fields: ${lib.concatStringsSep ", " missingFields}"
     else block;
   ```

6. **Policy Enforcement**:
   ```nix
   enforcePolicy = { blocks, policies }: let
     # Apply each policy to each block
     applyPolicy = policy: block:
       if policy.predicate block
       then block
       else throw "Policy violation: ${policy.message}";
     
     applyPolicies = block:
       lib.foldl' (b: policy: applyPolicy policy b) block policies;
   in
     map applyPolicies blocks;
   ```

## Migration Roadmap

1. **Phase 1: Library Implementation (Week 1)**
   - Create `lib/codegen.nix` with the meta-block API
   - Implement core functions and validation helpers
   - Write unit tests for the library

2. **Phase 2: Prototype Transformers (Week 2)**
   - Refactor one transformer of each type (JSON-Schema, Protobuf, Vector)
   - Validate that the meta-block API meets all requirements
   - Adjust the API based on feedback

3. **Phase 3: Collector Integration (Week 3)**
   - Implement the meta-block collector
   - Refactor one collector to use the new system
   - Ensure registry generation works correctly

4. **Phase 4: CI Integration (Week 4)**
   - Implement validation checks in CI pipeline
   - Create test cases for each structural guarantee
   - Document the validation process

5. **Phase 5: Full Migration (Weeks 5-8)**
   - Refactor remaining transformers to use meta-blocks
   - Update collectors to use the new system
   - Ensure backward compatibility during transition

6. **Phase 6: Documentation & Training (Week 9)**
   - Create comprehensive documentation
   - Provide examples for common use cases
   - Train team members on the new system

## Structural Guarantee Test Cases

1. **Type Safety Test**:
   ```nix
   testTypeSafety = let
     block = mkCodegenBlock {
       name = "test";
       description = "Test block";
       blockType = "test";
       schema = {
         value = {
           type = "int";
           required = true;
         };
       };
     } { name = "test"; value = "not an int"; };
   in
     assert false; # Should throw an error
     block
   ```

2. **Composition Constraints Test**:
   ```nix
   testComposition = let
     blocks = [
       (mkPipelineBlock {
         name = "pipeline";
         description = "Test pipeline";
         blockType = "pipeline";
       } { name = "pipeline"; steps = ["nonexistent-step"]; system = "x86_64-linux"; })
     ];
   in
     assert false; # Should throw an error
     validateComposition blocks
   ```

3. **Duplication Elimination Test**:
   ```nix
   testDuplication = let
     blocks = [
       (mkCodegenBlock {
         name = "test";
         description = "Test block";
         blockType = "test";
       } { name = "duplicate"; })
       (mkCodegenBlock {
         name = "test";
         description = "Test block";
         blockType = "test";
       } { name = "duplicate"; })
     ];
   in
     assert false; # Should throw an error
     detectDuplication blocks
   ```

4. **Early Error Detection Test**:
   ```nix
   testEarlyErrors = let
     block = mkCodegenBlock {
       name = "test";
       description = "Test block";
       blockType = "test";
       schema = {
         value = {
           type = "int";
           required = true;
         };
       };
     } { name = "test"; }; # Missing required field
   in
     assert false; # Should throw an error
     validateParameters block
   ```

5. **Safe Parameterization Test**:
   ```nix
   testSafeParams = let
     block = mkCodegenBlock {
       name = "test";
       description = "Test block";
       blockType = "test";
       schema = {
         value = {
           type = "int";
           required = true;
         };
       };
     } { name = "test"; value = 42; extraField = "unexpected"; };
   in
     assert block.value == 42;
     block
   ```

6. **Policy Enforcement Test**:
   ```nix
   testPolicyEnforcement = let
     blocks = [
       (mkCodegenBlock {
         name = "test";
         description = "Test block";
         blockType = "test";
       } { name = "test"; outputPath = "/tmp/insecure"; })
     ];
     policies = [
       {
         predicate = block: !(block ? outputPath) || lib.hasPrefix "generated/" block.outputPath;
         message = "Output paths must be under the generated/ directory";
       }
     ];
   in
     assert false; # Should throw an error
     enforcePolicy { inherit blocks policies; }
   ```
