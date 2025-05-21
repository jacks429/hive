{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "versioning";
  type = "versioning";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    versioningRule = inputs.${fragment}.${target};
    
    # Generate documentation
    generateDocs = ''
      mkdir -p $PRJ_ROOT/docs/versioning
      cat > $PRJ_ROOT/docs/versioning/${target}.md << EOF
      ${versioningRule.documentation}
      EOF
      echo "Documentation generated at docs/versioning/${target}.md"
    '';
    
    # Generate validator script
    generateValidator = ''
      mkdir -p $PRJ_ROOT/scripts/versioning
      cat > $PRJ_ROOT/scripts/versioning/validate-${target}.sh << EOF
      ${versioningRule.versionValidator}
      EOF
      chmod +x $PRJ_ROOT/scripts/versioning/validate-${target}.sh
      echo "Validator script generated at scripts/versioning/validate-${target}.sh"
    '';
    
    # Generate bumper script
    generateBumper = ''
      mkdir -p $PRJ_ROOT/scripts/versioning
      cat > $PRJ_ROOT/scripts/versioning/bump-${target}.sh << EOF
      ${versioningRule.versionBumper}
      EOF
      chmod +x $PRJ_ROOT/scripts/versioning/bump-${target}.sh
      echo "Bumper script generated at scripts/versioning/bump-${target}.sh"
    '';
    
    # Validate a version
    validateVersion = ''
      if [ $# -lt 1 ]; then
        echo "Error: Missing version argument"
        echo "Usage: validate-version VERSION"
        exit 1
      fi
      
      VERSION="$1"
      $PRJ_ROOT/scripts/versioning/validate-${target}.sh "$VERSION"
    '';
    
    # Bump a version
    bumpVersion = ''
      if [ $# -lt 2 ]; then
        echo "Error: Missing arguments"
        echo "Usage: bump-version VERSION BUMP_TYPE"
        echo "BUMP_TYPE can be: major, minor, patch, prerelease"
        exit 1
      fi
      
      VERSION="$1"
      BUMP_TYPE="$2"
      $PRJ_ROOT/scripts/versioning/bump-${target}.sh "$VERSION" "$BUMP_TYPE"
    '';
    
    # Apply versioning to a file
    applyToFile = ''
      if [ $# -lt 2 ]; then
        echo "Error: Missing arguments"
        echo "Usage: apply-to-file FILE VERSION"
        exit 1
      fi
      
      FILE="$1"
      VERSION="$2"
      
      # Validate version first
      VALID=$($PRJ_ROOT/scripts/versioning/validate-${target}.sh "$VERSION" 2>/dev/null) || {
        echo "Error: Invalid version format"
        exit 1
      }
      
      # Update version in file based on file type
      case "$FILE" in
        *.nix)
          # For Nix files, update version attribute
          sed -i 's/version = "[^"]*"/version = "'$VERSION'"/g' "$FILE"
          sed -i 's/version = [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/version = "'$VERSION'"/g' "$FILE"
          ;;
        *.json)
          # For JSON files, update version field
          sed -i 's/"version": "[^"]*"/"version": "'$VERSION'"/g' "$FILE"
          ;;
        *.yaml|*.yml)
          # For YAML files, update version field
          sed -i 's/version: [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/version: '$VERSION'/g' "$FILE"
          ;;
        *)
          echo "Unsupported file type: $FILE"
          exit 1
          ;;
      esac
      
      echo "Updated version in $FILE to $VERSION"
    '';
    
    # Check versions across the project
    checkVersions = ''
      echo "Checking versions for ${target} rules..."
      
      # Find all relevant files based on appliesTo
      case "${versioningRule.appliesTo}" in
        all|pipelines)
          echo "Checking pipeline versions..."
          find $PRJ_ROOT/cells -path "*/pipelines/*.nix" -type f | while read file; do
            VERSION=$(grep -o 'version = "[^"]*"' "$file" | sed 's/version = "\(.*\)"/\1/')
            if [ -n "$VERSION" ]; then
              VALID=$($PRJ_ROOT/scripts/versioning/validate-${target}.sh "$VERSION" 2>/dev/null) || {
                echo "❌ Invalid version in $file: $VERSION"
                continue
              }
              echo "✅ $file: $VERSION → $VALID"
            fi
          done
          ;;
        all|datasets)
          echo "Checking dataset versions..."
          find $PRJ_ROOT/cells -path "*/datasets/*.nix" -type f | while read file; do
            VERSION=$(grep -o 'version = "[^"]*"' "$file" | sed 's/version = "\(.*\)"/\1/')
            if [ -n "$VERSION" ]; then
              VALID=$($PRJ_ROOT/scripts/versioning/validate-${target}.sh "$VERSION" 2>/dev/null) || {
                echo "❌ Invalid version in $file: $VERSION"
                continue
              }
              echo "✅ $file: $VERSION → $VALID"
            fi
          done
          ;;
        all|models)
          echo "Checking model versions..."
          find $PRJ_ROOT/cells -path "*/modelRegistry/*.nix" -type f | while read file; do
            VERSION=$(grep -o 'version = "[^"]*"' "$file" | sed 's/version = "\(.*\)"/\1/')
            if [ -n "$VERSION" ]; then
              VALID=$($PRJ_ROOT/scripts/versioning/validate-${target}.sh "$VERSION" 2>/dev/null) || {
                echo "❌ Invalid version in $file: $VERSION"
                continue
              }
              echo "✅ $file: $VERSION → $VALID"
            fi
          done
          ;;
        all|microservices)
          echo "Checking microservice versions..."
          find $PRJ_ROOT/cells -path "*/microservices/*.nix" -type f | while read file; do
            VERSION=$(grep -o 'version = "[^"]*"' "$file" | sed 's/version = "\(.*\)"/\1/')
            if [ -n "$VERSION" ]; then
              VALID=$($PRJ_ROOT/scripts/versioning/validate-${target}.sh "$VERSION" 2>/dev/null) || {
                echo "❌ Invalid version in $file: $VERSION"
                continue
              }
              echo "✅ $file: $VERSION → $VALID"
            fi
          done
          ;;
      esac
      
      echo "Version check complete"
    '';
  in [
    (mkCommand currentSystem {
      name = "generate-docs";
      description = "Generate versioning documentation";
      command = generateDocs;
    })
    (mkCommand currentSystem {
      name = "generate-validator";
      description = "Generate version validator script";
      command = generateValidator;
    })
    (mkCommand currentSystem {
      name = "generate-bumper";
      description = "Generate version bumper script";
      command = generateBumper;
    })
    (mkCommand currentSystem {
      name = "validate-version";
      description = "Validate a version against rules";
      command = validateVersion;
    })
    (mkCommand currentSystem {
      name = "bump-version";
      description = "Bump a version according to semver rules";
      command = bumpVersion;
    })
    (mkCommand currentSystem {
      name = "apply-to-file";
      description = "Apply version to a file";
      command = applyToFile;
    })
    (mkCommand currentSystem {
      name = "check-versions";
      description = "Check versions across the project";
      command = checkVersions;
    })
  ];
}
