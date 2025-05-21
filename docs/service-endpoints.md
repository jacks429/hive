# Dynamic Service Endpoints in Hive

This document explains how to use the dynamic service endpoints system in Hive.

## Overview

Service endpoints define network interfaces for your microservices and external dependencies. The dynamic service endpoints system allows you to:

1. Define endpoints that adapt to different deployment environments
2. Use expressions and functions to dynamically resolve endpoint properties
3. Reference other endpoints and services for composition
4. Generate documentation, environment variables, and hosts entries

## Defining a Service Endpoint

Service endpoints are defined in the `serviceEndpoints` block of a cell. Here's a basic example:

```nix
{
  inputs,
  cell,
}: { config, ... }: {
  name = "my-service";
  system = "x86_64-linux";
  type = "http";
  service = "my-microservice";  # Reference to a microservice
  
  # Deployment environment (can be overridden)
  deploymentEnv = "dev";
  
  # Connection details
  host = "my-service.local";
  port = 8080;
  path = "/api/v1";
  
  # Optional metadata
  metadata = {
    description = "My service endpoint";
    tags = ["api" "internal"];
  };
}
```

## Dynamic Properties

Any property can be a function that receives context and returns a value:

```nix
{
  inputs,
  cell,
}: { config, ... }: {
  name = "dynamic-service";
  system = "x86_64-linux";
  type = "http";
  
  # Dynamic deployment environment
  deploymentEnv = config.deploymentEnv or "dev";
  
  # Dynamic host based on environment
  host = ctx: 
    if ctx.deploymentEnv == "prod" then "service.example.com"
    else if ctx.deploymentEnv == "staging" then "service.staging.example.com"
    else "service.local";
  
  # Dynamic port based on environment
  port = ctx: 
    if ctx.deploymentEnv == "prod" then 443
    else 8080;
}
```

## Accessing the Service Endpoints Registry

The service endpoints registry provides access to all endpoints and helper functions:

```nix
# Get the registry
serviceEndpointsRegistry = inputs.self.serviceEndpointsRegistry (cell: target: "${cell}-${target}");

# Get all endpoints
allEndpoints = serviceEndpointsRegistry.registry;

# Get endpoints by environment
prodEndpoints = serviceEndpointsRegistry.getEndpointsByEnv "prod";

# Get endpoints by type
httpEndpoints = serviceEndpointsRegistry.getEndpointsByType "http";

# Get endpoints by service
apiEndpoints = serviceEndpointsRegistry.getEndpointsByService "api-service";

# Get endpoints by tag
internalEndpoints = serviceEndpointsRegistry.getEndpointsByTag "internal";

# Find endpoints by custom criteria
customEndpoints = serviceEndpointsRegistry.findEndpoints [
  { type = "http"; }
  { deploymentEnv = "prod"; }
  { metadata = { highAvailability = true; }; }
];

# Get hosts entries for all endpoints
hostsEntries = serviceEndpointsRegistry.hostsEntries;

# Get environment variables script for all endpoints
envScript = serviceEndpointsRegistry.envScript;

# Get environment-specific outputs
stagingRegistry = serviceEndpointsRegistry.byEnv.staging.registry;
stagingHostsEntries = serviceEndpointsRegistry.byEnv.staging.hostsEntries;
stagingEnvScript = serviceEndpointsRegistry.byEnv.staging.envScript;
```

## Integration with Microservices and Workflows

Service endpoints are automatically integrated with microservices and workflows:

1. Microservices receive environment variables and service flags from their endpoints
2. Workflows receive environment variables for all endpoints used by their pipelines
3. Deployment configurations can use endpoint information for network setup

## Available Endpoint Types

The system supports the following endpoint types:

- `http`: HTTP endpoints
- `https`: HTTPS endpoints
- `grpc`: gRPC endpoints
- `tcp`: TCP endpoints
- `udp`: UDP endpoints
- `socket`: Unix socket endpoints

Each type has specific properties and generates appropriate connection strings and test commands.