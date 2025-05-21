{
  inputs,
  cell,
}: {
  name = "semver";
  description = "Standard Semantic Versioning rules";
  
  # Target type this versioning rule applies to
  appliesTo = "all"; # "all", "pipelines", "datasets", "models", "microservices"
  
  # Version pattern to enforce (semver by default)
  pattern = "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$";
  
  # Version extraction rules
  extractFrom = {
    attribute = "version"; # Default attribute to extract version from
    fallback = "0.1.0";    # Default version if not found
  };
  
  # Version validation rules
  validation = {
    required = true;       # Whether version is required
    allowPrerelease = false; # Whether pre-release versions are allowed in production
    allowBuildMetadata = true; # Whether build metadata is allowed
  };
  
  # Version increment rules
  increment = {
    major = "Breaking changes";
    minor = "New features, backwards compatible";
    patch = "Bug fixes, backwards compatible";
  };
  
  # Version display format
  format = "v{major}.{minor}.{patch}{prerelease}{buildMetadata}";
}