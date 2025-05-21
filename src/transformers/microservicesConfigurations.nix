{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract service definition
  service = config.config;
  
  # Process service configuration
  processedService = {
    inherit (service) name system;
    container = service.container or {};
    networking = service.networking or {};
    dependencies = service.dependencies or [];
    # Add additional processing as needed
  };
  
  # Get service endpoints registry with dynamic resolution
  serviceEndpointsRegistry = root.collectors.serviceEndpointsRegistry (cell: target: "${cell}-${target}");

  # Find endpoints for this service
  serviceEndpoints = serviceEndpointsRegistry.findEndpoints [
    { service = microservice.name; }
  ];

  # Add service endpoints to the microservice configuration
  microserviceWithEndpoints = microservice // {
    # Add endpoints information
    endpoints = serviceEndpoints;
    
    # Enhance the runner script to use endpoint configuration
    runner = let
      # Get the original runner script
      originalRunner = microservice.runner;
      
      # Generate additional environment setup for endpoints
      endpointsEnvSetup = l.concatMapStrings (name: endpoint: ''
        # Environment variables for ${name} endpoint
        ${l.concatMapStrings (varName: ''
          export ${varName}="${endpoint.envVars.${varName}}"
        '') (l.attrNames endpoint.envVars)}
        
      '') serviceEndpoints;
      
      # Generate service flags based on endpoints
      endpointsServiceFlags = l.concatMapStrings (name: endpoint: 
        if endpoint.service == microservice.name then
          ''
          # Service flags for ${name} endpoint
          SERVICE_FLAGS+=" ${endpoint.serviceFlags}"
          ''
        else ""
      ) serviceEndpoints;
      
      # Create a new runner script that includes endpoint information
      newRunnerScript = ''
        #!/usr/bin/env bash
        set -e
        
        # Setup environment variables for service endpoints
        ${endpointsEnvSetup}
        
        # Initialize service flags
        SERVICE_FLAGS=""
        
        # Add endpoint-specific service flags
        ${endpointsServiceFlags}
        
        # Run the original service with the enhanced flags
        ${originalRunner} $SERVICE_FLAGS "$@"
      '';
      
      # Create a new runner derivation
      newRunnerDrv = pkgs.writeScriptBin "run-${microservice.name}" newRunnerScript;
    in
      newRunnerDrv;
  };
  
  # Get environments registry
  environmentsRegistry = root.collectors.environmentsRegistry renamer;

  # Function to create an environment-aware runner
  createEnvironmentAwareRunner = envName: let
    # Get environment variables
    envVars = environmentsRegistry.getEnvironmentVariables envName;
    
    # Get environment resources
    resources = environmentsRegistry.getEnvironmentResources envName;
    
    # Get environment services
    services = environmentsRegistry.getEnvironmentServices envName;
    
    # Create environment-specific runner script
    envRunnerScript = ''
      #!/usr/bin/env bash
      set -e
      
      # Set environment name
      export ENVIRONMENT="${envName}"
      
      # Set environment variables
      ${l.concatMapStrings (name: "export ${name}=\"${envVars.${name}}\"\n") 
        (l.attrNames envVars)}
      
      echo "🟢 Running microservice ${microservice.name} in ${envName} environment"
      
      # Apply resource limits if specified
      ${l.optionalString (resources ? cpu) ''
        export CPU_LIMIT="${resources.cpu}"
        echo "  CPU limit: ${resources.cpu}"
      ''}
      ${l.optionalString (resources ? memory) ''
        export MEMORY_LIMIT="${resources.memory}"
        echo "  Memory limit: ${resources.memory}"
      ''}
      
      # Override service endpoints if specified
      ${l.concatMapStrings (name: ''
        export ${name}_URL="${services.${name}}"
        echo "  Service ${name}: ${services.${name}}"
      '') (l.attrNames services)}
      
      # Execute the original runner with environment context
      ${microservice.runner}/bin/run-${microservice.name} "$@"
    '';
    
    # Create environment-specific runner derivation
    envRunnerDrv = pkgs.writeScriptBin "run-${microservice.name}-in-${envName}" envRunnerScript;
  in
    envRunnerDrv;

  # Create environment-specific runners for all environments
  environmentRunners = l.listToAttrs (
    l.map (envName: 
      l.nameValuePair 
        envName 
        (createEnvironmentAwareRunner envName)
    ) environmentsRegistry.getEnvironmentNames
  );

  # Create a runner that accepts an environment argument
  environmentSelectableRunnerScript = ''
    #!/usr/bin/env bash
    set -e
    
    # Default to dev environment if not specified
    ENVIRONMENT="dev"
    
    # Parse command line arguments
    ARGS=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --environment=*)
          ENVIRONMENT="''${1#*=}"
          shift
          ;;
        --environment)
          ENVIRONMENT="$2"
          shift 2
          ;;
        *)
          ARGS+=("$1")
          shift
          ;;
      esac
    done
    
    # Check if the environment exists
    if [[ ! -f "${pkgs.stdenv.mkDerivation {
      name = "environment-runners";
      phases = ["installPhase"];
      installPhase = ''
        mkdir -p $out/bin
        ${l.concatMapStrings (envName: ''
          touch $out/bin/${envName}
        '') environmentsRegistry.getEnvironmentNames}
      '';
    }}/bin/$ENVIRONMENT" ]]; then
      echo "Error: Environment '$ENVIRONMENT' not found"
      echo "Available environments: ${l.concatStringsSep ", " environmentsRegistry.getEnvironmentNames}"
      exit 1
    fi
    
    # Run the microservice with the selected environment
    exec ${pkgs.stdenv.mkDerivation {
      name = "environment-runner-selector";
      phases = ["installPhase"];
      installPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/select-environment <<EOF
        #!/usr/bin/env bash
        case "\$ENVIRONMENT" in
        ${l.concatMapStrings (envName: ''
          ${envName})
            exec ${environmentRunners.${envName}}/bin/run-${microservice.name}-in-${envName} "\$@"
            ;;
        '') environmentsRegistry.getEnvironmentNames}
        esac
        EOF
        chmod +x $out/bin/select-environment
      '';
    }}/bin/select-environment "''${ARGS[@]}"
  '';

  # Create environment-selectable runner derivation
  environmentSelectableRunnerDrv = pkgs.writeScriptBin "run-${microservice.name}-with-env" environmentSelectableRunnerScript;

  # Add environment support to the microservice configuration
  microserviceWithEnvironments = {
    # Original microservice data
    inherit (microservice) name system description;
    
    # Enhanced outputs
    runner = microservice.runner;
    
    # Add environment-specific runners
    environmentRunners = environmentRunners;
    environmentSelectableRunner = environmentSelectableRunnerDrv;
    
    # Add metadata for microservice execution
    metadata = microservice.metadata or {};
  };
  
in
  microserviceWithEnvironments
