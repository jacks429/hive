{ inputs, nixpkgs, root }:

let
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self "topicModels" (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: topicModels - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        
        # Model configuration
        framework = config.framework or "gensim";
        modelUri = config.modelUri or "";
        modelType = "topicModels";
        numTopics = config.numTopics or 10;
        params = config.params or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ]);
in
  walk
