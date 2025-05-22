{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self "classifiers" (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: classifiers - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        
        # Model configuration
        framework = config.framework or "huggingface";
        modelUri = config.modelUri or "";
        task = "classification";
        params = config.params or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ]);
in
  walk
