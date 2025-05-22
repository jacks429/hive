{
  inputs,
  cell,
}: {
  name = "calver";
  description = "Calendar Versioning rules (YYYY.MM.MICRO)";
  
  # Target type this versioning rule applies to
  appliesTo = "datasets"; # Apply only to datasets
  
  # Version pattern to enforce (CalVer YYYY.MM.MICRO)
  pattern = "^(20[0-9]{2})\\.(0[1-9]|1[0-2])\\.([0-9]+)$";
  
  # Version extraction rules
  extractFrom = {
    attribute = "version"; # Default attribute to extract version from
    fallback = "2023.01.0"; # Default version if not found
  };
  
  # Version validation rules
  validation = {
    required = true;       # Whether version is required
    allowPrerelease = false; # Not applicable for CalVer
    allowBuildMetadata = false; # Not applicable for CalVer
  };
  
  # Version increment rules
  increment = {
    major = "New year";
    minor = "New month";
    patch = "New release within month";
  };
  
  # Version display format
  format = "{major}.{minor}.{patch}";
}