{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "versioning";
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        
        # Target type this versioning rule applies to
        appliesTo = config.appliesTo or "all"; # "all", "pipelines", "datasets", "models", "microservices"
        
        # Version pattern to enforce (semver by default)
        pattern = config.pattern or "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$";
        
        # Version extraction rules
        extractFrom = config.extractFrom or {
          attribute = "version"; # Default attribute to extract version from
          fallback = "0.1.0";    # Default version if not found
        };
        
        # Version validation rules
        validation = config.validation or {
          required = true;       # Whether version is required
          allowPrerelease = false; # Whether pre-release versions are allowed in production
          allowBuildMetadata = true; # Whether build metadata is allowed
        };
        
        # Version increment rules
        increment = config.increment or {
          major = "Breaking changes";
          minor = "New features, backwards compatible";
          patch = "Bug fixes, backwards compatible";
        };
        
        # Version display format
        format = config.format or "v{major}.{minor}.{patch}";
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk