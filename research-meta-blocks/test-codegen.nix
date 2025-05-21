# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ lib, pkgs }:

let
  # Import our experimental codegen library
  codegen = import ./lib/codegen.nix { inherit lib pkgs; };
  
  # Test valid configuration
  testValid = let
    result = codegen.mkCodegenBlock {
      name = "test";
      description = "Test block";
      blockType = "test";
      schema = {
        name = {
          description = "Name";
          type = "string";
          required = true;
        };
        value = {
          description = "Value";
          type = "int";
          required = true;
        };
      };
    } { 
      name = "test-instance"; 
      value = 42;
      system = "x86_64-linux";
    };
  in
    assert result.name == "test-instance";
    assert result.value == 42;
    assert result._type == "test";
    true;
  
  # Test invalid configuration (missing required field)
  testInvalidMissing = let
    result = builtins.tryEval (
      codegen.mkCodegenBlock {
        name = "test";
        description = "Test block";
        blockType = "test";
        schema = {
          name = {
            description = "Name";
            type = "string";
            required = true;
          };
          value = {
            description = "Value";
            type = "int";
            required = true;
          };
        };
      } { 
        name = "test-instance";
        # Missing value field
        system = "x86_64-linux";
      }
    );
  in
    assert !result.success;
    true;
  
  # Test invalid configuration (wrong type)
  testInvalidType = let
    result = builtins.tryEval (
      codegen.mkCodegenBlock {
        name = "test";
        description = "Test block";
        blockType = "test";
        schema = {
          name = {
            description = "Name";
            type = "string";
            required = true;
          };
          value = {
            description = "Value";
            type = "int";
            required = true;
          };
        };
      } { 
        name = "test-instance";
        value = "not an int"; # Wrong type
        system = "x86_64-linux";
      }
    );
  in
    assert !result.success;
    true;
    
  # Test vector block
  testVectorBlock = let
    result = codegen.mkVectorBlock {
      name = "test-vectors";
      description = "Test vector block";
      blockType = "vectorCollection";
    } {
      name = "test-vectors";
      description = "Test vector collection";
      dimensions = 512;
      system = "x86_64-linux";
    };
  in
    assert result.name == "test-vectors";
    assert result.dimensions == 512;
    assert result._type == "vectorCollection";
    true;
    
  # Test duplication detection
  testDuplication = let
    blocks = [
      {
        name = "block1";
        _type = "test";
      }
      {
        name = "block1"; # Duplicate name
        _type = "test";
      }
    ];
    result = builtins.tryEval (codegen.detectDuplication blocks);
  in
    assert !result.success;
    true;
in
{
  # Run all tests
  allTests = testValid && testInvalidMissing && testInvalidType && 
             testVectorBlock && testDuplication;
}
