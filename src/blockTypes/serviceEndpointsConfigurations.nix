{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;

  serviceEndpoints = {
    name = "serviceEndpoints";
    type = "endpoint";
    transform = import ../transformers/serviceEndpointsConfigurations.nix;
    
    actions = {
      currentSystem,
      fragment,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
      endpoint = inputs.${fragment}.${target};
      
      # Support for dynamic deployment environment
      deploymentEnv = endpoint.deploymentEnv or "dev";
      
      # Generate documentation with deployment context
      generateDocs = ''
        cat > endpoint-${target}-${deploymentEnv}.md << EOF
        # Service Endpoint: ${target} (${deploymentEnv})
        
        **Type:** ${endpoint.type}
        **Service:** ${if endpoint.service != null then endpoint.service else "standalone"}
        **URL:** \`${endpoint.url}\`
        **Deployment Environment:** ${deploymentEnv}
        
        ## Connection Details
        - Host: \`${endpoint.host}\`
        - Port: \`${toString endpoint.port}\`
        ${l.optionalString (endpoint.path != null) "- Path: \`${endpoint.path}\`"}
        
        ## Testing
        \`\`\`bash
        ${endpoint.testCommand}
        \`\`\`
        
        ## Environment Variables
        ${l.concatMapStrings (name: "- \`${name}=${endpoint.envVars.${name}}\`\n") 
          (l.attrNames endpoint.envVars)}
        
        ${l.optionalString (endpoint.hostsEntry != null) ''
        ## Hosts Entry
        \`\`\`
        ${endpoint.hostsEntry}
        \`\`\`
        ''}
        
        ${l.optionalString (endpoint ? metadata) ''
        ## Metadata
        ${l.concatMapStrings (key: "- ${key}: ${endpoint.metadata.${key}}\n") 
          (l.attrNames endpoint.metadata)}
        ''}
        EOF
        
        echo "Documentation generated at endpoint-${target}-${deploymentEnv}.md"
      '';
      
      # Generate hosts file entries
      generateHostsEntries = ''
        ${if endpoint.hostsEntry != null then ''
          echo "${endpoint.hostsEntry}"
        '' else ''
          echo "No hosts entry needed for ${target} in ${deploymentEnv} environment"
        ''}
      '';
      
      # Generate environment variables export script
      generateEnvScript = ''
        cat > ${target}-${deploymentEnv}-env.sh << EOF
        #!/usr/bin/env bash
        # Environment variables for ${target} endpoint in ${deploymentEnv} environment
        ${l.concatMapStrings (name: "export ${name}=\"${endpoint.envVars.${name}}\"\n") 
          (l.attrNames endpoint.envVars)}
        EOF
        
        chmod +x ${target}-${deploymentEnv}-env.sh
        echo "Environment script generated at ${target}-${deploymentEnv}-env.sh"
      '';
      
      # Test the endpoint
      testEndpoint = ''
        echo "Testing endpoint ${target} in ${deploymentEnv} environment..."
        ${endpoint.testCommand}
      '';
      
      # Generate service flags for use in service runners
      generateServiceFlags = ''
        echo "Service flags for ${target} in ${deploymentEnv} environment:"
        echo "${endpoint.serviceFlags}"
      '';
      
    in [
      (mkCommand currentSystem {
        name = "docs";
        description = "Generate endpoint documentation";
        command = generateDocs;
      })
      (mkCommand currentSystem {
        name = "hosts";
        description = "Generate hosts file entry";
        command = generateHostsEntries;
      })
      (mkCommand currentSystem {
        name = "env";
        description = "Generate environment variables script";
        command = generateEnvScript;
      })
      (mkCommand currentSystem {
        name = "test";
        description = "Test the endpoint";
        command = testEndpoint;
      })
      (mkCommand currentSystem {
        name = "url";
        description = "Print the endpoint URL";
        command = ''
          echo "${endpoint.url}"
        '';
      })
      (mkCommand currentSystem {
        name = "flags";
        description = "Print service flags for this endpoint";
        command = generateServiceFlags;
      })
      (mkCommand currentSystem {
        name = "info";
        description = "Print all endpoint information";
        command = ''
          echo "Endpoint: ${target} (${deploymentEnv})"
          echo "Type: ${endpoint.type}"
          echo "Service: ${if endpoint.service != null then endpoint.service else "standalone"}"
          echo "URL: ${endpoint.url}"
          echo "Host: ${endpoint.host}"
          echo "Port: ${toString endpoint.port}"
          ${l.optionalString (endpoint.path != null) ''echo "Path: ${endpoint.path}"''}
          echo ""
          echo "Service Flags:"
          echo "${endpoint.serviceFlags}"
          echo ""
          echo "Environment Variables:"
          ${l.concatMapStrings (name: ''echo "${name}=${endpoint.envVars.${name}}"'') 
            (l.attrNames endpoint.envVars)}
        '';
      })
    ];
  };
in
  serviceEndpoints
