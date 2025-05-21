# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  transformers = import ../lib/transformers.nix { inherit lib pkgs; };
in
pkgs.runCommand "transformers-tests" {} ''
  # Test withDefaults
  echo "Testing withDefaults..."
  ${pkgs.writeScript "test-withDefaults" ''
    #!/usr/bin/env nix-instantiate --eval
    let
      pkgs = import <nixpkgs> {};
      lib = pkgs.lib;
      transformers = import ${../lib/transformers.nix} { inherit lib pkgs; };
      
      config = { a = 1; c = 3; };
      defaults = { a = 0; b = 2; };
      result = transformers.withDefaults config defaults;
      expected = { a = 1; b = 2; c = 3; };
    in
      if result == expected
      then builtins.trace "withDefaults: PASS" true
      else builtins.trace "withDefaults: FAIL - Expected ${builtins.toJSON expected} but got ${builtins.toJSON result}" false
  ''}
  
  # Test validateConfig
  echo "Testing validateConfig..."
  ${pkgs.writeScript "test-validateConfig" ''
    #!/usr/bin/env nix-instantiate --eval
    let
      pkgs = import <nixpkgs> {};
      lib = pkgs.lib;
      transformers = import ${../lib/transformers.nix} { inherit lib pkgs; };
      
      schema = {
        a = { type = "int"; required = true; };
        b = { type = "string"; required = false; };
      };
      
      # Valid config
      validConfig = { a = 1; b = "test"; };
      validResult = transformers.validateConfig validConfig schema;
      
      # Invalid config (missing required field)
      invalidConfig1 = { b = "test"; };
      invalidTest1 = builtins.tryEval (transformers.validateConfig invalidConfig1 schema);
      
      # Invalid config (wrong type)
      invalidConfig2 = { a = "not an int"; b = "test"; };
      invalidTest2 = builtins.tryEval (transformers.validateConfig invalidConfig2 schema);
    in
      if validResult == validConfig && !invalidTest1.success && !invalidTest2.success
      then builtins.trace "validateConfig: PASS" true
      else builtins.trace "validateConfig: FAIL" false
  ''}
  
  # Test withArgs
  echo "Testing withArgs..."
  ${pkgs.writeScript "test-withArgs" ''
    #!/usr/bin/env nix-instantiate --eval
    let
      pkgs = import <nixpkgs> {};
      lib = pkgs.lib;
      transformers = import ${../lib/transformers.nix} { inherit lib pkgs; };
      
      script = "echo Hello, \$name!";
      result = transformers.withArgs {
        name = "greet";
        description = "Greet someone";
        args = [
          { name = "name"; description = "Name to greet"; required = true; position = 0; }
        ];
      } script;
      
      # Check if the result contains the script
      containsScript = builtins.match ".*echo Hello, \\\$name!.*" result != null;
      
      # Check if the result contains help text
      containsHelp = builtins.match ".*Usage: greet <name>.*" result != null;
    in
      if containsScript && containsHelp
      then builtins.trace "withArgs: PASS" true
      else builtins.trace "withArgs: FAIL" false
  ''}
  
  # Test generateDocs
  echo "Testing generateDocs..."
  ${pkgs.writeScript "test-generateDocs" ''
    #!/usr/bin/env nix-instantiate --eval
    let
      pkgs = import <nixpkgs> {};
      lib = pkgs.lib;
      transformers = import ${../lib/transformers.nix} { inherit lib pkgs; };
      
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
      
      # Check if the docs contain the name
      containsName = builtins.match ".*# test-tool.*" docs != null;
      
      # Check if the docs contain the description
      containsDescription = builtins.match ".*A test tool.*" docs != null;
      
      # Check if the docs contain the parameter
      containsParam = builtins.match ".*### example.*" docs != null;
    in
      if containsName && containsDescription && containsParam
      then builtins.trace "generateDocs: PASS" true
      else builtins.trace "generateDocs: FAIL" false
  ''}
  
  # Test mkScript
  echo "Testing mkScript..."
  ${pkgs.writeScript "test-mkScript" ''
    #!/usr/bin/env nix-instantiate --eval
    let
      pkgs = import <nixpkgs> {};
      lib = pkgs.lib;
      transformers = import ${../lib/transformers.nix} { inherit lib pkgs; };
      
      script = transformers.mkScript {
        name = "test-script";
        description = "A test script";
        script = "echo Hello, world!";
      };
      
      # Check if the script is a derivation
      isDerivation = builtins.isAttrs script && script ? type && script.type == "derivation";
      
      # Check if the script has the right name
      hasRightName = script.name == "test-script";
    in
      if isDerivation && hasRightName
      then builtins.trace "mkScript: PASS" true
      else builtins.trace "mkScript: FAIL" false
  ''}
  
  # Test mkModelTransformer
  echo "Testing mkModelTransformer..."
  ${pkgs.writeScript "test-mkModelTransformer" ''
    #!/usr/bin/env nix-instantiate --eval
    let
      pkgs = import <nixpkgs> {};
      lib = pkgs.lib;
      transformers = import ${../lib/transformers.nix} { inherit lib pkgs; };
      
      model = transformers.mkModelTransformer {
        name = "test-model";
        description = "A test model";
        modelUri = "test-uri";
        framework = "test-framework";
        params = { param1 = "value1"; };
        service = { enable = true; };
      };
      
      # Check if the model has the right attributes
      hasRightAttrs = model.name == "test-model" && 
                      model.modelUri == "test-uri" && 
                      model.framework == "test-framework";
      
      # Check if the model has the right derivations
      hasRightDerivations = model ? runner && model ? service && model ? docs && model ? package;
      
      # Check if the service is enabled
      serviceEnabled = model.service.enable;
    in
      if hasRightAttrs && hasRightDerivations && serviceEnabled
      then builtins.trace "mkModelTransformer: PASS" true
      else builtins.trace "mkModelTransformer: FAIL" false
  ''}
  
  # Run all tests
  echo "Running all tests..."
  ${pkgs.writeScript "run-all-tests" ''
    #!/usr/bin/env bash
    set -e
    
    echo "=== Transformers Library Tests ==="
    
    # Run withDefaults test
    echo -n "withDefaults: "
    if nix-instantiate --eval ${./test-withDefaults} 2>/dev/null | grep -q "withDefaults: PASS"; then
      echo "PASS"
    else
      echo "FAIL"
      exit 1
    fi
    
    # Run validateConfig test
    echo -n "validateConfig: "
    if nix-instantiate --eval ${./test-validateConfig} 2>/dev/null | grep -q "validateConfig: PASS"; then
      echo "PASS"
    else
      echo "FAIL"
      exit 1
    fi
    
    # Run withArgs test
    echo -n "withArgs: "
    if nix-instantiate --eval ${./test-withArgs} 2>/dev/null | grep -q "withArgs: PASS"; then
      echo "PASS"
    else
      echo "FAIL"
      exit 1
    fi
    
    # Run generateDocs test
    echo -n "generateDocs: "
    if nix-instantiate --eval ${./test-generateDocs} 2>/dev/null | grep -q "generateDocs: PASS"; then
      echo "PASS"
    else
      echo "FAIL"
      exit 1
    fi
    
    # Run mkScript test
    echo -n "mkScript: "
    if nix-instantiate --eval ${./test-mkScript} 2>/dev/null | grep -q "mkScript: PASS"; then
      echo "PASS"
    else
      echo "FAIL"
      exit 1
    fi
    
    # Run mkModelTransformer test
    echo -n "mkModelTransformer: "
    if nix-instantiate --eval ${./test-mkModelTransformer} 2>/dev/null | grep -q "mkModelTransformer: PASS"; then
      echo "PASS"
    else
      echo "FAIL"
      exit 1
    fi
    
    echo "All tests passed!"
  ''}
  
  # Create a success marker
  touch $out
''
