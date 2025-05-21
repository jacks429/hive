{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all service endpoints
  endpoints = root.collectors.serviceEndpointsConfigurations renamer;
  
  # Create a registry of endpoint definitions, keyed by name
  endpointsRegistry = l.mapAttrs (name: endpoint: {
    inherit (endpoint) name system type service;
    inherit (endpoint) host port url connectionString;
    path = endpoint.path or null;
    hostsEntry = endpoint.hostsEntry;
    envVars = endpoint.envVars;
    metadata = endpoint.metadata or {};
    deploymentEnv = endpoint.deploymentEnv or "dev";
  }) endpoints;
  
  # Group endpoints by deployment environment
  endpointsByEnv = l.groupBy 
    (endpoint: endpoint.deploymentEnv or "dev") 
    (l.attrValues endpointsRegistry);
  
  # Generate combined documentation for all endpoints
  allEndpointsDocs = let
    endpointsList = l.mapAttrsToList (name: endpoint: ''
      ## Endpoint: ${name} (${endpoint.deploymentEnv})
      
      **Type:** ${endpoint.type}
      **Service:** ${if endpoint.service != null then endpoint.service else "standalone"}
      **URL:** \`${endpoint.url}\`
      
      ### Connection Details
      - Host: \`${endpoint.host}\`
      - Port: \`${toString endpoint.port}\`
      ${l.optionalString (endpoint.path != null) "- Path: \`${endpoint.path}\`"}
      
      ${l.optionalString (endpoint ? metadata) ''
      ### Metadata
      ${l.concatMapStrings (key: "- ${key}: ${endpoint.metadata.${key}}\n") 
        (l.attrNames endpoint.metadata)}
      ''}
      
      ---
    '') endpointsRegistry;
  in ''
    # Service Endpoints Registry
    
    This document contains information about all available service endpoints.
    
    ${l.concatStringsSep "\n" endpointsList}
  '';
  
  # Generate combined hosts file entries by environment
  combinedHostsEntriesByEnv = l.mapAttrs (env: endpoints: 
    let
      validEntries = l.filter (entry: entry.hostsEntry != null) endpoints;
    in
      l.concatStringsSep "\n" (map (e: e.hostsEntry) validEntries)
  ) endpointsByEnv;
  
  # Generate combined environment variables script by environment
  combinedEnvScriptByEnv = l.mapAttrs (env: endpoints: 
    let
      allVars = l.foldl' (acc: endpoint: 
        acc // endpoint.envVars
      ) {} endpoints;
    in ''
      #!/usr/bin/env bash
      # Combined environment variables for all service endpoints in ${env} environment
      
      ${l.concatMapStrings (name: "export ${name}=\"${allVars.${name}}\"\n") 
        (l.attrNames allVars)}
    ''
  ) endpointsByEnv;
  
  # Generate combined hosts file entries for all environments
  combinedHostsEntries = let
    validEntries = l.filter (entry: entry != null) 
      (l.mapAttrsToList (name: endpoint: endpoint.hostsEntry) endpointsRegistry);
  in
    l.concatStringsSep "\n" validEntries;
  
  # Generate combined environment variables script for all environments
  combinedEnvScript = let
    allVars = l.foldl' (acc: endpoint: 
      acc // endpoint.envVars
    ) {} (l.attrValues endpointsRegistry);
  in ''
    #!/usr/bin/env bash
    # Combined environment variables for all service endpoints
    
    ${l.concatMapStrings (name: "export ${name}=\"${allVars.${name}}\"\n") 
      (l.attrNames allVars)}
  '';
  
  # Function to filter endpoints by criteria
  filterEndpoints = criteria:
    l.filterAttrs (name: endpoint:
      let
        # Check if endpoint matches all criteria
        matches = l.all (criterion:
          let
            key = l.head (l.attrNames criterion);
            value = criterion.${key};
          in
            # Handle special case for metadata
            if key == "metadata" then
              l.all (metaKey:
                endpoint ? metadata && 
                endpoint.metadata ? ${metaKey} && 
                endpoint.metadata.${metaKey} == value.${metaKey}
              ) (l.attrNames value)
            # Handle regular attributes
            else if endpoint ? ${key} then
              # Support for list values (any match)
              if l.isList value then
                l.elem endpoint.${key} value
              # Support for function predicates
              else if l.isFunction value then
                value endpoint.${key}
              # Direct comparison
              else
                endpoint.${key} == value
            else
              false
        ) criteria;
      in
        matches
    ) endpointsRegistry;
  
in {
  registry = endpointsRegistry;
  documentation = allEndpointsDocs;
  hostsEntries = combinedHostsEntries;
  envScript = combinedEnvScript;
  
  # Environment-specific registries and outputs
  byEnv = l.mapAttrs (env: endpoints: {
    registry = l.filterAttrs (_: e: (e.deploymentEnv or "dev") == env) endpointsRegistry;
    hostsEntries = combinedHostsEntriesByEnv.${env};
    envScript = combinedEnvScriptByEnv.${env};
  }) endpointsByEnv;
  
  # Helper function to get service flags for a specific endpoint
  getServiceFlags = endpointName:
    if l.hasAttr endpointName endpointsRegistry then
      endpoints.${endpointName}.serviceFlags
    else
      throw "Endpoint not found: ${endpointName}";
  
  # Helper function to get environment variables for a specific endpoint
  getEnvVars = endpointName:
    if l.hasAttr endpointName endpointsRegistry then
      endpoints.${endpointName}.envVars
    else
      throw "Endpoint not found: ${endpointName}";
      
  # Helper function to find endpoints by criteria
  findEndpoints = filterEndpoints;
  
  # Helper function to get endpoints by type
  getEndpointsByType = type:
    filterEndpoints [{ inherit type; }];
    
  # Helper function to get endpoints by service
  getEndpointsByService = service:
    filterEndpoints [{ inherit service; }];
    
  # Helper function to get endpoints by environment
  getEndpointsByEnv = deploymentEnv:
    filterEndpoints [{ inherit deploymentEnv; }];
    
  # Helper function to get endpoints by tag (in metadata)
  getEndpointsByTag = tag:
    filterEndpoints [{ 
      metadata = { 
        tags = value: l.isList value && l.elem tag value;
      }; 
    }];
}
