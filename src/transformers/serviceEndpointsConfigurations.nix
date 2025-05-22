{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract endpoint definition with support for dynamic resolution
  endpoint = config;
  
  # Get microservices registry
  microservicesRegistry = root.collectors.microservices (cell: target: "${cell}-${target}");
  
  # Support for dynamic service reference resolution
  resolveServiceReference = serviceName:
    if l.isFunction serviceName then
      serviceName { 
        inherit microservicesRegistry;
        inherit (root) collectors;
      }
    else
      serviceName;
  
  # Resolve the service reference
  resolvedService = resolveServiceReference endpoint.service;
  
  # Validate service reference
  validateServiceReference = 
    if resolvedService != null && !(l.hasAttr resolvedService microservicesRegistry) then
      throw "Service endpoint ${endpoint.name} references non-existent service: ${resolvedService}"
    else
      true;
  
  # Check that service reference is valid
  _ = validateServiceReference;
  
  # Support for dynamic host resolution
  resolveHost = host:
    if l.isFunction host then
      host {
        inherit (endpoint) name type service system;
        inherit (root) collectors;
        deploymentEnv = endpoint.deploymentEnv or "dev";
      }
    else
      host;
  
  # Resolve the host
  resolvedHost = resolveHost endpoint.host;
  
  # Support for dynamic port resolution
  resolvePort = port:
    if l.isFunction port then
      port {
        inherit (endpoint) name type service system;
        inherit (root) collectors;
        deploymentEnv = endpoint.deploymentEnv or "dev";
      }
    else
      port;
  
  # Resolve the port
  resolvedPort = resolvePort endpoint.port;
  
  # Support for dynamic path resolution
  resolvePath = path:
    if path == null then null
    else if l.isFunction path then
      path {
        inherit (endpoint) name type service system;
        inherit (root) collectors;
        deploymentEnv = endpoint.deploymentEnv or "dev";
      }
    else
      path;
  
  # Resolve the path
  resolvedPath = resolvePath (endpoint.path or null);
  
  # Process endpoint based on type with dynamic resolution
  processedEndpoint = 
    if endpoint.type == "http" || endpoint.type == "https" then 
      processHttpEndpoint { 
        inherit (endpoint) type; 
        host = resolvedHost; 
        port = resolvedPort; 
        path = resolvedPath;
      }
    else if endpoint.type == "grpc" then 
      processGrpcEndpoint { 
        inherit (endpoint) type; 
        host = resolvedHost; 
        port = resolvedPort;
        protoFile = endpoint.protoFile or null;
      }
    else if endpoint.type == "socket" then 
      processSocketEndpoint {
        inherit (endpoint) type;
        path = resolvedPath;
      }
    else if endpoint.type == "tcp" then 
      processTcpEndpoint {
        inherit (endpoint) type;
        host = resolvedHost;
        port = resolvedPort;
      }
    else if endpoint.type == "udp" then 
      processUdpEndpoint {
        inherit (endpoint) type;
        host = resolvedHost;
        port = resolvedPort;
      }
    else endpoint; # Pass through if type is unknown
  
  # Process HTTP/HTTPS endpoint
  processHttpEndpoint = args: {
    url = "${args.type}://${args.host}:${toString args.port}${args.path or "/"}";
    connectionString = "${args.type}://${args.host}:${toString args.port}${args.path or "/"}";
    
    # Generate curl command for testing
    testCommand = ''
      curl -v ${if args.type == "https" then "-k " else ""}${args.type}://${args.host}:${toString args.port}${args.path or "/"}
    '';
    
    # Generate service flags for HTTP endpoints
    serviceFlags = ''
      --host ${args.host} --port ${toString args.port}
    '';
  };
  
  # Process gRPC endpoint
  processGrpcEndpoint = args: {
    url = "${args.host}:${toString args.port}";
    connectionString = "${args.host}:${toString args.port}";
    
    # Generate grpcurl command for testing (if proto file is provided)
    testCommand = if args ? protoFile && args.protoFile != null then ''
      grpcurl -plaintext -proto ${args.protoFile} ${args.host}:${toString args.port} list
    '' else ''
      echo "No proto file specified for gRPC endpoint testing"
    '';
    
    # Generate service flags for gRPC endpoints
    serviceFlags = ''
      --grpc-host ${args.host} --grpc-port ${toString args.port}
    '';
  };
  
  # Process Unix socket endpoint
  processSocketEndpoint = args: {
    url = "unix:${args.path}";
    connectionString = args.path;
    
    # Generate test command for socket
    testCommand = ''
      if [ -S ${args.path} ]; then
        echo "Socket exists at ${args.path}"
      else
        echo "Socket does not exist at ${args.path}"
      fi
    '';
    
    # Generate service flags for socket endpoints
    serviceFlags = ''
      --socket ${args.path}
    '';
  };
  
  # Process TCP endpoint
  processTcpEndpoint = args: {
    url = "tcp://${args.host}:${toString args.port}";
    connectionString = "${args.host}:${toString args.port}";
    
    # Generate test command for TCP
    testCommand = ''
      nc -zv ${args.host} ${toString args.port}
    '';
    
    # Generate service flags for TCP endpoints
    serviceFlags = ''
      --host ${args.host} --port ${toString args.port}
    '';
  };
  
  # Process UDP endpoint
  processUdpEndpoint = args: {
    url = "udp://${args.host}:${toString args.port}";
    connectionString = "${args.host}:${toString args.port}";
    
    # Generate test command for UDP
    testCommand = ''
      nc -zuv ${args.host} ${toString args.port}
    '';
    
    # Generate service flags for UDP endpoints
    serviceFlags = ''
      --host ${args.host} --port ${toString args.port} --udp
    '';
  };
  
  # Support for dynamic IP address resolution
  resolveIpAddress = ipAddress:
    if ipAddress == null then null
    else if l.isFunction ipAddress then
      ipAddress {
        inherit (endpoint) name type service system;
        host = resolvedHost;
        deploymentEnv = endpoint.deploymentEnv or "dev";
      }
    else
      ipAddress;
  
  # Resolve IP address
  resolvedIpAddress = resolveIpAddress (endpoint.ipAddress or null);
  
  # Generate hosts file entry with dynamic resolution
  hostsEntry = 
    if resolvedHost != "localhost" && resolvedHost != "127.0.0.1" && !(l.hasPrefix ":" resolvedHost) then
      "${if resolvedIpAddress != null then resolvedIpAddress else "127.0.0.1"} ${resolvedHost}"
    else
      null;
  
  # Generate environment variables for this endpoint with dynamic resolution
  envVars = {
    "${l.toUpper (l.replaceStrings ["-" "."] ["_" "_"] endpoint.name)}_URL" = processedEndpoint.url;
    "${l.toUpper (l.replaceStrings ["-" "."] ["_" "_"] endpoint.name)}_HOST" = resolvedHost;
    "${l.toUpper (l.replaceStrings ["-" "."] ["_" "_"] endpoint.name)}_PORT" = toString resolvedPort;
  } // (if endpoint.type == "socket" then {
    "${l.toUpper (l.replaceStrings ["-" "."] ["_" "_"] endpoint.name)}_SOCKET" = resolvedPath;
  } else {});
  
  # Support for dynamic metadata resolution
  resolveMetadata = metadata:
    if metadata == null then {}
    else if l.isFunction metadata then
      metadata {
        inherit (endpoint) name type service system;
        host = resolvedHost;
        port = resolvedPort;
        path = resolvedPath;
        deploymentEnv = endpoint.deploymentEnv or "dev";
      }
    else
      metadata;
  
  # Resolve metadata
  resolvedMetadata = resolveMetadata (endpoint.metadata or {});
  
in {
  # Original endpoint data with resolved values
  inherit (endpoint) name system type;
  service = resolvedService;
  host = resolvedHost;
  port = resolvedPort;
  path = resolvedPath;
  
  # Enhanced outputs
  url = processedEndpoint.url;
  connectionString = processedEndpoint.connectionString;
  testCommand = processedEndpoint.testCommand;
  serviceFlags = processedEndpoint.serviceFlags;
  hostsEntry = hostsEntry;
  envVars = envVars;
  
  # Add metadata for endpoint usage
  metadata = resolvedMetadata;
  
  # Include deployment environment for context
  deploymentEnv = endpoint.deploymentEnv or "dev";
}
