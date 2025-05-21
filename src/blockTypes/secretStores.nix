{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "secretStores";
  type = "secretStore";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    secretStore = inputs.${fragment}.${target};
    
    # Generate documentation
    generateDocs = ''
      mkdir -p $PRJ_ROOT/docs/secret-stores
      cat > $PRJ_ROOT/docs/secret-stores/${target}.md << EOF
      ${secretStore.documentation}
      EOF
      echo "Documentation generated at docs/secret-stores/${target}.md"
    '';
    
    # Generate backend configuration
    generateBackendConfig = 
      if secretStore.backend == "sops" then ''
        mkdir -p $PRJ_ROOT/secrets
        cat > $PRJ_ROOT/secrets/.sops.yaml << EOF
        ${secretStore.backendConfiguration.sopsConfig}
        EOF
        echo "SOPS configuration generated at secrets/.sops.yaml"
      ''
      else if secretStore.backend == "vault" then ''
        mkdir -p $PRJ_ROOT/secrets
        cat > $PRJ_ROOT/secrets/vault.hcl << EOF
        ${secretStore.backendConfiguration.vaultConfig}
        EOF
        echo "Vault configuration generated at secrets/vault.hcl"
      ''
      else if secretStore.backend == "aws-secretsmanager" then ''
        mkdir -p $PRJ_ROOT/secrets
        cat > $PRJ_ROOT/secrets/aws-secretsmanager.json << EOF
        {
          "region": "${secretStore.backendConfiguration.region}",
          "profile": "${secretStore.backendConfiguration.profile}"
        }
        EOF
        echo "AWS Secrets Manager configuration generated at secrets/aws-secretsmanager.json"
      ''
      else ''
        echo "No configuration generated for backend: ${secretStore.backend}"
      '';
    
    # Generate rotation scripts for rotatable secrets
    generateRotationScripts = ''
      mkdir -p $PRJ_ROOT/secrets/rotation
      
      ${l.concatMapStrings (secret: 
        if secret.rotatable or false then ''
          cat > $PRJ_ROOT/secrets/rotation/${secretStore.name}-${secret.name}-rotate.sh << EOF
          #!/usr/bin/env bash
          set -euo pipefail
          
          echo "Rotating secret: ${secret.name}"
          
          ${secret.rotationCommand or "echo \"No rotation command specified\""}
          
          echo "Secret rotation completed"
          EOF
          chmod +x $PRJ_ROOT/secrets/rotation/${secretStore.name}-${secret.name}-rotate.sh
          echo "Rotation script generated at secrets/rotation/${secretStore.name}-${secret.name}-rotate.sh"
        '' else ""
      ) secretStore.secrets}
    '';
    
    # Generate access control configuration
    generateAccessControl = ''
      mkdir -p $PRJ_ROOT/secrets/access
      cat > $PRJ_ROOT/secrets/access/${secretStore.name}-access.json << EOF
      ${builtins.toJSON secretStore.accessControlConfig}
      EOF
      echo "Access control configuration generated at secrets/access/${secretStore.name}-access.json"
    '';
    
  in [
    (mkCommand currentSystem {
      name = "docs";
      description = "Generate documentation for the secret store";
      command = generateDocs;
    })
    (mkCommand currentSystem {
      name = "config";
      description = "Generate backend configuration for the secret store";
      command = generateBackendConfig;
    })
    (mkCommand currentSystem {
      name = "rotation";
      description = "Generate rotation scripts for rotatable secrets";
      command = generateRotationScripts;
    })
    (mkCommand currentSystem {
      name = "access";
      description = "Generate access control configuration";
      command = generateAccessControl;
    })
    (mkCommand currentSystem {
      name = "setup";
      description = "Set up the complete secret store";
      command = ''
        ${generateDocs}
        ${generateBackendConfig}
        ${generateRotationScripts}
        ${generateAccessControl}
        
        echo "Secret store ${secretStore.name} set up successfully"
      '';
    })
  ];
}
