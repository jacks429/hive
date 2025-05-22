{
  inputs,
  cell,
}: {
  name = "taxonomy-versioning";
  description = "Versioning rules for taxonomies";
  
  # Target type this versioning rule applies to
  appliesTo = "taxonomies";
  
  # Version pattern to enforce (CalVer YYYY.MM.MICRO)
  pattern = "^(20[0-9]{2})\\.(0[1-9]|1[0-2])\\.([0-9]+)$";
  
  # Version extraction rules
  extractFrom = {
    attribute = "metadata.version"; # Extract version from metadata
    fallback = "2023.01.0"; # Default version if not found
  };
  
  # Version validation rules
  validation = {
    required = true;
    allowPrerelease = false;
    allowBuildMetadata = false;
  };
  
  # Taxonomy-specific versioning rules
  taxonomyRules = {
    # Track changes to the taxonomy structure
    structureChanges = {
      major = [
        "categories" # Adding/removing top-level categories is a major change
      ];
      minor = [
        "categories.*.children" # Adding/removing subcategories is a minor change
      ];
      patch = [
        "categories.*.description" # Updating descriptions is a patch change
        "metadata.*" # Updating metadata is a patch change
      ];
    };
  };
}