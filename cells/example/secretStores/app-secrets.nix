{
  inputs,
  cell,
}: {
  name = "app-secrets";
  description = "Secret store for application credentials and sensitive configuration";
  
  # Backend configuration
  backend = "sops";
  backendConfig = {
    sopsFile = "secrets/app-secrets.yaml";
    pathRegex = "secrets/.*\\.yaml$";
    pgpKeys = [
      "ABCDEF1234567890ABCDEF1234567890ABCDEF12" # Example key fingerprint
    ];
    ageKeys = [
      "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p" # Example age key
    ];
  };
  
  # Secrets
  secrets = [
    {
      name = "database-credentials";
      description = "Database connection credentials";
      type = "json";
      path = "secrets/database.yaml";
      rotatable = true;
      rotationSchedule = "0 0 1 * *"; # Monthly rotation
      rotationCommand = ''
        # Generate new database credentials
        NEW_PASSWORD=$(openssl rand -base64 32)
        
        # Update the database
        echo "Updating database password..."
        
        # Update the secret
        echo "Updating secret in store..."
      '';
      tags = ["database" "credentials"];
    }
    {
      name = "api-keys";
      description = "External API access keys";
      type = "json";
      path = "secrets/api-keys.yaml";
      rotatable = true;
      rotationSchedule = "0 0 1 */3 *"; # Quarterly rotation
      tags = ["api" "credentials"];
    }
    {
      name = "ssl-certificate";
      description = "SSL certificate for HTTPS";
      type = "certificate";
      path = "secrets/ssl-cert.yaml";
      rotatable = true;
      rotationSchedule = "0 0 1 */6 *"; # Bi-annual rotation
      tags = ["ssl" "certificate"];
    }
    {
      name = "encryption-key";
      description = "Encryption key for sensitive data";
      type = "key";
      path = "secrets/encryption-key.yaml";
      rotatable = false;
      tags = ["encryption" "key"];
    }
  ];
  
  # Access control
  accessControl = {
    roles = [
      {
        name = "admin";
        description = "Full access to all secrets";
        permissions = ["read" "write" "rotate"];
        members = ["admin-team"];
      }
      {
        name = "app-service";
        description = "Application service access";
        permissions = ["read"];
        members = ["app-service-account"];
      }
      {
        name = "security-team";
        description = "Security team access for rotation";
        permissions = ["read" "rotate"];
        members = ["security-team"];
      }
    ];
  };
}