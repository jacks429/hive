{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract all secrets from the store
  allSecrets = config.secrets or [];
  
  # Extract backend configuration
  backend = config.backend or "sops";
  backendConfig = config.backendConfig or {};
  
  # Generate backend-specific configuration
  backendConfiguration = 
    if backend == "sops" then {
      sopsFile = backendConfig.sopsFile or ".sops.yaml";
      sopsConfig = ''
        creation_rules:
          - path_regex: ${backendConfig.pathRegex or ".*"}
            key_groups:
              - pgp:
                ${l.concatMapStrings (key: "  - ${key}\n") (backendConfig.pgpKeys or [])}
              ${if backendConfig ? ageKeys then "- age:\n${l.concatMapStrings (key: "  - ${key}\n") backendConfig.ageKeys}" else ""}
      '';
    }
    else if backend == "vault" then {
      vaultAddress = backendConfig.address or "https://vault.example.com:8200";
      vaultToken = backendConfig.token or "";
      vaultConfig = ''
        vault {
          address = "${backendConfig.address or "https://vault.example.com:8200"}"
          ${if backendConfig ? token then "token = \"${backendConfig.token}\"" else ""}
          ${if backendConfig ? role then "role = \"${backendConfig.role}\"" else ""}
          ${if backendConfig ? authPath then "auth_path = \"${backendConfig.authPath}\"" else ""}
        }
      '';
    }
    else if backend == "aws-secretsmanager" then {
      region = backendConfig.region or "us-east-1";
      profile = backendConfig.profile or "default";
    }
    else {};
  
  # Generate secret access configuration
  secretAccessConfig = l.listToAttrs (l.map (secret: {
    name = secret.name;
    value = {
      path = secret.path;
      type = secret.type or "string";
    };
  }) allSecrets);
  
  # Generate access control configuration
  accessControlConfig = l.listToAttrs (l.map (role: {
    name = role.name;
    value = {
      permissions = role.permissions;
      members = role.members or [];
    };
  }) (config.accessControl.roles or []));
  
  # Generate documentation
  documentation = ''
    # Secret Store: ${config.name}
    
    ${config.description or ""}
    
    ## Backend: ${backend}
    
    ${if backend == "sops" then ''
      This secret store uses SOPS for secret management.
      
      ### Configuration
      
      - **SOPS File**: ${backendConfiguration.sopsFile}
      
      ```yaml
      ${backendConfiguration.sopsConfig}
      ```
    '' else if backend == "vault" then ''
      This secret store uses HashiCorp Vault for secret management.
      
      ### Configuration
      
      - **Vault Address**: ${backendConfiguration.vaultAddress}
      
      ```hcl
      ${backendConfiguration.vaultConfig}
      ```
    '' else if backend == "aws-secretsmanager" then ''
      This secret store uses AWS Secrets Manager for secret management.
      
      ### Configuration
      
      - **Region**: ${backendConfiguration.region}
      - **Profile**: ${backendConfiguration.profile}
    '' else ''
      This secret store uses ${backend} for secret management.
    ''}
    
    ## Secrets
    
    ${l.concatMapStrings (secret: ''
      ### ${secret.name}
      
      ${secret.description or ""}
      
      - **Type**: ${secret.type or "string"}
      - **Path**: ${secret.path}
      - **Rotatable**: ${if secret.rotatable or false then "Yes" else "No"}
      ${if secret ? rotationSchedule then "- **Rotation Schedule**: ${secret.rotationSchedule}\n" else ""}
      ${if (secret.tags or []) != [] then "- **Tags**: ${l.concatStringsSep ", " secret.tags}\n" else ""}
      
    '') allSecrets}
    
    ## Access Control
    
    ${l.concatMapStrings (role: ''
      ### ${role.name}
      
      ${role.description or ""}
      
      - **Permissions**: ${l.concatStringsSep ", " role.permissions}
      ${if (role.members or []) != [] then "- **Members**: ${l.concatStringsSep ", " role.members}\n" else ""}
      
    '') (config.accessControl.roles or [])}
  '';
  
  # Return the processed secret store with generated outputs
  result = config // {
    backendConfiguration = backendConfiguration;
    secretAccessConfig = secretAccessConfig;
    accessControlConfig = accessControlConfig;
    documentation = documentation;
  };
in
  result
