{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "taxonomies";
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
        
        # Taxonomy structure
        categories = config.categories or {};
        
        # Format options
        format = config.format or "hierarchical"; # hierarchical, flat, etc.
        
        # Optional metadata
        metadata = config.metadata or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk