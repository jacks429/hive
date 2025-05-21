# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ nixpkgs, root, inputs }:

let
  # Import our experimental codegen library
  codegen = import ./lib/codegen.nix { 
    inherit (nixpkgs) lib; 
    pkgs = nixpkgs.legacyPackages.x86_64-linux; 
  };
in

config: codegen.mkCodegenBlock {
  name = "test-transformer";
  description = "Test transformer using meta-block API";
  blockType = "test";
  schema = {
    name = {
      description = "Name of the test resource";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the test resource";
      type = "string";
      required = false;
    };
    value = {
      description = "Test value";
      type = "int";
      required = true;
    };
    system = {
      description = "System for which this resource is defined";
      type = "string";
      required = true;
    };
  };
  processConfig = config: {
    inherit (config) name description value system;
    processed = true;
    timestamp = builtins.currentTime or 0;
  };
} config
