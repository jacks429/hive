# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ lib, pkgs }:

let
  l = lib // builtins;
  # Import the existing transformers and collectors libraries
  transformers = import ../../lib/transformers.nix { inherit lib pkgs; };
  collectors = import ../../lib/collectors.nix { inherit lib pkgs; };
in rec {
  # Core meta-block factory - minimal version
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
    
    # Error handling
    withErrorContext ? true,
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
    
    # Combine results
    result = processedConfig // {
      _type = blockType;
      _meta = {
        inherit name description blockType schema;
      };
      documentation = docs;
    };
  in
    result;

  # Meta-block for vector operations (as a simple example)
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
    };

  # Simple validation functions for structural guarantees
  
  # Type safety validation
  validateTypes = block: let
    schema = block._meta.schema or {};
    errors = l.mapAttrsToList (name: field:
      if block ? ${name} && field ? type && l.typeOf block.${name} != field.type
      then "Field '${name}' has type '${l.typeOf block.${name}}' but expected '${field.type}'"
      else null
    ) schema;
    realErrors = l.filter (e: e != null) errors;
  in
    if realErrors != [] then throw (l.concatStringsSep "\n" realErrors) else block;
  
  # Duplication detection
  detectDuplication = blocks: let
    blocksByName = l.groupBy (block: block.name) blocks;
    duplicates = l.filterAttrs (name: blocks: l.length blocks > 1) blocksByName;
  in
    if duplicates != {} 
    then throw "Duplicate blocks found: ${l.concatStringsSep ", " (l.attrNames duplicates)}"
    else blocks;
}
