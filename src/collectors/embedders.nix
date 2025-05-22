{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self "embedders" (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: embedders - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        
        # Model configuration
        framework = config.framework or "sentence-transformers";
        modelUri = config.modelUri or "";
        dimensions = config.dimensions or 384;
        params = config.params or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ]);
in
  walk
