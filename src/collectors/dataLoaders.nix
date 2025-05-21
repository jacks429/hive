{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "dataLoaders";
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
        
        # Source configuration
        source = {
          type = config.source.type or "file"; # file, s3, http, database, api
          location = config.source.location or "";
          credentials = config.source.credentials or null;
          options = config.source.options or {};
        };
        
        # Destination configuration (typically references a dataset)
        destination = {
          dataset = config.destination.dataset or "";
          format = config.destination.format or "raw";
          options = config.destination.options or {};
        };
        
        # Transformation to apply during loading (minimal)
        transform = config.transform or null;
        
        # Schedule information
        schedule = config.schedule or null;
        
        # Dependencies
        dependencies = config.dependencies or [];
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk