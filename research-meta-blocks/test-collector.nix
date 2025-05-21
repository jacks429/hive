# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ inputs, nixpkgs, root }:

let
  # Import our experimental codegen library
  codegen = import ./lib/codegen.nix { 
    inherit (nixpkgs) lib; 
    pkgs = nixpkgs.legacyPackages.x86_64-linux; 
  };
  # Import the existing collectors library
  collectors = import ../lib/collectors.nix { 
    inherit (nixpkgs) lib; 
    pkgs = nixpkgs.legacyPackages.x86_64-linux; 
  };
in

renamer: let
  cellBlock = "test";
  l = nixpkgs.lib // builtins;
  
  # Process test configuration
  processConfig = config: {
    inherit (config) name description value system;
    processed = true;
    timestamp = builtins.currentTime or 0;
  };
  
  # Create the collector using the library function
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;
  
  # Create a registry of test items
  createRegistry = items: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = items;
      keyFn = name: item: item.name;
    };
    
    # Generate documentation for the registry
    registryDocs = ''
      # Test Registry
      
      This registry contains ${toString (l.length (l.attrNames registry))} test items.
      
      ## Items
      
      ${l.concatMapStrings (item: ''
        - **${item.name}**: ${item.description or ""} (value: ${toString item.value})
      '') (l.attrValues registry)}
    '';
  in {
    items = registry;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;
  
  # Return a function to create a registry
  registry = createRegistry;
}
