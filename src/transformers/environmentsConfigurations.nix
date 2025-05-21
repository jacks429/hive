{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract environment definition
  environment = config;
  
  # Create environment variables script
  envVarsScript = ''
    #!/usr/bin/env bash
    # Environment variables for ${environment.name} environment
    
    ${l.concatMapStrings (name: "export ${name}=\"${environment.variables.${name}}\"\n") 
      (l.attrNames (environment.variables or {}))}
  '';
  
  # Create environment variables script derivation
  envVarsDrv = pkgs.writeScriptBin "env-${environment.name}" envVarsScript;
  
  # Create a JSON representation of the environment
  envJson = l.toJSON {
    inherit (environment) name description;
    resources = environment.resources or {};
    services = environment.services or {};
    variables = environment.variables or {};
    metadata = environment.metadata or {};
  };
  
  # Create a JSON file derivation
  envJsonDrv = pkgs.writeTextFile {
    name = "${environment.name}-environment.json";
    text = envJson;
  };
  
  # Create a wrapper script that sets up the environment
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    # Source environment variables
    source ${envVarsDrv}/bin/env-${environment.name}
    
    # Execute the command with the environment set up
    exec "$@"
  '';
  
  # Create a wrapper script derivation
  wrapperDrv = pkgs.writeScriptBin "with-env-${environment.name}" wrapperScript;
  
in {
  # Original environment data
  inherit (environment) name description system;
  inherit (environment) overlays resources services secrets variables;
  
  # Enhanced outputs
  envVars = envVarsDrv;
  envJson = envJsonDrv;
  wrapper = wrapperDrv;
  
  # Add metadata
  metadata = environment.metadata or {};
}