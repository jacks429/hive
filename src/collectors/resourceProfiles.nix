{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "resourceProfiles";
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
        
        # Resource specifications
        resources = {
          cpu = config.cpu or "1";
          memory = config.memory or "1GiB";
          gpu = config.gpu or null;
          storage = config.storage or "10GiB";
        } // (config.resources or {});
        
        # Additional metadata
        comment = config.comment or "";
        tags = config.tags or [];
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Create a registry of resource profiles
  profileRegistry = l.mapAttrs (name: profile: {
    inherit (profile) name description resources comment tags system;
  }) (walk inputs);
in
  profileRegistry