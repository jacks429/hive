{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "datasetCatalog";
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
        
        # Dataset information
        uri = config.uri or "";
        license = config.license or "Unknown";
        sha256 = config.sha256 or "";
        maintainer = config.maintainer or "";
        
        # Lineage and tags
        lineage = config.lineage or [];
        tags = config.tags or [];
        
        # Additional metadata
        metadata = config.metadata or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Create a catalog of datasets
  datasetCatalog = l.mapAttrs (name: dataset: {
    inherit (dataset) name description uri license sha256 maintainer lineage tags metadata system;
  }) (walk inputs);
in
  datasetCatalog