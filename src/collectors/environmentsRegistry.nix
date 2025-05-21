{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all environment configurations
  environments = root.collectors.environmentsConfigurations renamer;
  
  # Create a registry of environment definitions, keyed by name
  environmentsRegistry = l.listToAttrs (
    l.map (env: l.nameValuePair env.name env) (l.attrValues environments)
  );
  
  # Function to get an environment by name
  getEnvironment = name:
    if l.hasAttr name environmentsRegistry
    then environmentsRegistry.${name}
    else throw "Environment not found: ${name}";
    
  # Function to get all environment names
  getEnvironmentNames = l.attrNames environmentsRegistry;
    
  # Function to merge environment overlays into a configuration
  mergeEnvironmentOverlays = envName: config:
    let
      env = getEnvironment envName;
    in
      l.recursiveUpdate config (env.overlays or {});
    
  # Function to get environment variables
  getEnvironmentVariables = envName:
    let
      env = getEnvironment envName;
    in
      env.variables or {};
    
  # Function to get environment resources
  getEnvironmentResources = envName:
    let
      env = getEnvironment envName;
    in
      env.resources or {};
    
  # Function to get environment services
  getEnvironmentServices = envName:
    let
      env = getEnvironment envName;
    in
      env.services or {};
    
  # Function to get environment secrets
  getEnvironmentSecrets = envName:
    let
      env = getEnvironment envName;
    in
      env.secrets or {};
    
  # Generate documentation for all environments
  allEnvironmentsDocs = let
    environmentsList = l.mapAttrsToList (name: env: ''
      ## Environment: ${name}
      
      ${env.description}
      
      ### Resources
      
      ${l.concatMapStrings (key: "- ${key}: ${l.toJSON env.resources.${key}}\n") 
        (l.attrNames (env.resources or {}))}
      
      ### Services
      
      ${l.concatMapStrings (key: "- ${key}: ${l.toJSON env.services.${key}}\n") 
        (l.attrNames (env.services or {}))}
      
      ### Variables
      
      ${l.concatMapStrings (key: "- ${key}: ${l.toJSON env.variables.${key}}\n") 
        (l.attrNames (env.variables or {}))}
      
      ---
    '') environmentsRegistry;
  in ''
    # Environments Registry
    
    This document contains information about all available environments.
    
    ${l.concatStringsSep "\n" environmentsList}
  '';
  
  # Generate environment variables script for a specific environment
  generateEnvScript = envName:
    let
      env = getEnvironment envName;
      variables = env.variables or {};
    in ''
      #!/usr/bin/env bash
      # Environment variables for ${envName} environment
      
      ${l.concatMapStrings (name: "export ${name}=\"${variables.${name}}\"\n") 
        (l.attrNames variables)}
    '';
  
in {
  registry = environmentsRegistry;
  documentation = allEnvironmentsDocs;
  
  # Helper functions
  getEnvironment = getEnvironment;
  getEnvironmentNames = getEnvironmentNames;
  mergeEnvironmentOverlays = mergeEnvironmentOverlays;
  getEnvironmentVariables = getEnvironmentVariables;
  getEnvironmentResources = getEnvironmentResources;
  getEnvironmentServices = getEnvironmentServices;
  getEnvironmentSecrets = getEnvironmentSecrets;
  generateEnvScript = generateEnvScript;
}