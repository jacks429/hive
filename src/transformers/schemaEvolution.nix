{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract schema evolution definition
  schema = {
    inherit (config) name description;
    migrations = config.migrations or [];
    current-version = config.current-version or "1.0.0";
    database-type = config.database-type or "postgresql";
  };
  
  # Generate migration scripts
  migrationScripts = l.listToAttrs (l.imap0 (idx: migration: {
    name = "migration-${builtins.toString idx}";
    value = {
      up = pkgs.writeTextFile {
        name = "migrate-${schema.name}-${migration.version}-up.sql";
        text = migration.up;
      };
      down = pkgs.writeTextFile {
        name = "migrate-${schema.name}-${migration.version}-down.sql";
        text = migration.down;
      };
      version = migration.version;
      description = migration.description or "";
    };
  }) schema.migrations);
  
  # Generate JSON schema file
  schemaJson = pkgs.writeTextFile {
    name = "${schema.name}-schema.json";
    text = builtins.toJSON {
      name = schema.name;
      description = schema.description;
      current-version = schema.current-version;
      database-type = schema.database-type;
      migrations = map (migration: {
        version = migration.version;
        description = migration.description or "";
      }) schema.migrations;
    };
  };
  
  # Generate markdown documentation
  schemaMd = pkgs.writeTextFile {
    name = "${schema.name}-schema.md";
    text = ''
      # Schema Evolution: ${schema.name}
      
      ${schema.description}
      
      ## Database Type
      
      ${schema.database-type}
      
      ## Current Version
      
      ${schema.current-version}
      
      ## Migration History
      
      ${l.concatMapStrings (migration: ''
      ### Version ${migration.version}
      
      ${migration.description or ""}
      
      #### Up Migration
      
      ```sql
      ${migration.up}
      ```
      
      #### Down Migration
      
      ```sql
      ${migration.down}
      ```
      
      '') schema.migrations}
    '';
  };
  
  # Create a command to apply migrations
  migrateScript = pkgs.writeShellScriptBin "migrate-${schema.name}" ''
    #!/usr/bin/env bash
    
    if [ $# -lt 2 ]; then
      echo "Usage: migrate-${schema.name} [up|down] TARGET_VERSION [DB_URL]"
      echo "Example: migrate-${schema.name} up 1.2.0 postgresql://user:pass@localhost:5432/mydb"
      exit 1
    fi
    
    DIRECTION="$1"
    TARGET_VERSION="$2"
    DB_URL="$3"
    
    if [ -z "$DB_URL" ]; then
      echo "Error: Database URL is required"
      exit 1
    fi
    
    echo "Migrating schema '${schema.name}' $DIRECTION to version $TARGET_VERSION"
    echo "Database: $DB_URL"
    echo ""
    
    # Determine which migrations to apply
    MIGRATIONS=(${l.concatStringsSep " " (map (m: m.version) schema.migrations)})
    CURRENT_VERSION="${schema.current-version}"
    
    # Sort migrations by version
    IFS=$'\n' SORTED_MIGRATIONS=($(sort -V <<<"''${MIGRATIONS[*]}"))
    unset IFS
    
    # Apply migrations
    if [ "$DIRECTION" = "up" ]; then
      for VERSION in "''${SORTED_MIGRATIONS[@]}"; do
        if ${pkgs.gnused}/bin/sed 's/\.//g' <<<"$VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//' | ${pkgs.gawk}/bin/awk -v target=$(${pkgs.gnused}/bin/sed 's/\.//g' <<<"$TARGET_VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//') '{exit ($1 > target)}'; then
          if ${pkgs.gnused}/bin/sed 's/\.//g' <<<"$VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//' | ${pkgs.gawk}/bin/awk -v current=$(${pkgs.gnused}/bin/sed 's/\.//g' <<<"$CURRENT_VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//') '{exit ($1 <= current)}'; then
            echo "Applying migration to version $VERSION..."
            
            # Find the migration script
            MIGRATION_SCRIPT=""
            for ((i=0; i<''${#MIGRATIONS[@]}; i++)); do
              if [ "''${MIGRATIONS[$i]}" = "$VERSION" ]; then
                MIGRATION_SCRIPT="${migrationScripts."migration-$i".up}"
                break
              fi
            done
            
            if [ -n "$MIGRATION_SCRIPT" ]; then
              # Apply the migration based on database type
              if [ "${schema.database-type}" = "postgresql" ]; then
                ${pkgs.postgresql}/bin/psql "$DB_URL" -f "$MIGRATION_SCRIPT"
              elif [ "${schema.database-type}" = "mysql" ]; then
                ${pkgs.mysql}/bin/mysql --defaults-extra-file=<(printf "[client]\nuser=%s\npassword=%s\nhost=%s\nport=%s\ndatabase=%s" \
                  $(echo "$DB_URL" | ${pkgs.gawk}/bin/awk -F '[/:@]' '{print $4, $5, $6, $7, $8}')) \
                  < "$MIGRATION_SCRIPT"
              elif [ "${schema.database-type}" = "sqlite" ]; then
                ${pkgs.sqlite}/bin/sqlite3 $(echo "$DB_URL" | ${pkgs.gnused}/bin/sed 's/sqlite:\/\///') < "$MIGRATION_SCRIPT"
              else
                echo "Unsupported database type: ${schema.database-type}"
                exit 1
              fi
              
              echo "Migration to version $VERSION completed."
            else
              echo "Error: Migration script for version $VERSION not found."
              exit 1
            fi
          fi
        fi
      done
    elif [ "$DIRECTION" = "down" ]; then
      # Reverse the sorted migrations for down migrations
      for ((i=''${#SORTED_MIGRATIONS[@]}-1; i>=0; i--)); do
        VERSION="''${SORTED_MIGRATIONS[$i]}"
        if ${pkgs.gnused}/bin/sed 's/\.//g' <<<"$VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//' | ${pkgs.gawk}/bin/awk -v target=$(${pkgs.gnused}/bin/sed 's/\.//g' <<<"$TARGET_VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//') '{exit ($1 < target)}'; then
          if ${pkgs.gnused}/bin/sed 's/\.//g' <<<"$VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//' | ${pkgs.gawk}/bin/awk -v current=$(${pkgs.gnused}/bin/sed 's/\.//g' <<<"$CURRENT_VERSION" | ${pkgs.gnused}/bin/sed 's/^0*//') '{exit ($1 > current)}'; then
            echo "Reverting migration from version $VERSION..."
            
            # Find the migration script
            MIGRATION_SCRIPT=""
            for ((j=0; j<''${#MIGRATIONS[@]}; j++)); do
              if [ "''${MIGRATIONS[$j]}" = "$VERSION" ]; then
                MIGRATION_SCRIPT="${migrationScripts."migration-$j".down}"
                break
              fi
            done
            
            if [ -n "$MIGRATION_SCRIPT" ]; then
              # Apply the migration based on database type
              if [ "${schema.database-type}" = "postgresql" ]; then
                ${pkgs.postgresql}/bin/psql "$DB_URL" -f "$MIGRATION_SCRIPT"
              elif [ "${schema.database-type}" = "mysql" ]; then
                ${pkgs.mysql}/bin/mysql --defaults-extra-file=<(printf "[client]\nuser=%s\npassword=%s\nhost=%s\nport=%s\ndatabase=%s" \
                  $(echo "$DB_URL" | ${pkgs.gawk}/bin/awk -F '[/:@]' '{print $4, $5, $6, $7, $8}')) \
                  < "$MIGRATION_SCRIPT"
              elif [ "${schema.database-type}" = "sqlite" ]; then
                ${pkgs.sqlite}/bin/sqlite3 $(echo "$DB_URL" | ${pkgs.gnused}/bin/sed 's/sqlite:\/\///') < "$MIGRATION_SCRIPT"
              else
                echo "Unsupported database type: ${schema.database-type}"
                exit 1
              fi
              
              echo "Migration from version $VERSION reverted."
            else
              echo "Error: Migration script for version $VERSION not found."
              exit 1
            fi
          fi
        fi
      done
    else
      echo "Error: Direction must be 'up' or 'down'"
      exit 1
    fi
    
    echo ""
    echo "Migration completed."
  '';
  
in {
  # Original schema configuration
  inherit (schema) name description;
  inherit (schema) migrations current-version database-type;
  
  # Derivations
  json = schemaJson;
  documentation = schemaMd;
  migrate = migrateScript;
  migration-scripts = migrationScripts;
  
  # Add metadata
  metadata = config.metadata or {};
}
