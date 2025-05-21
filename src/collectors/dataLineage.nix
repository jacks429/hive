{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "dataLineage";
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
        
        # Node definitions (data sources, transformations, targets)
        nodes = l.mapAttrs (name: node: {
          type = node.type or "dataset"; # dataset, table, file, api, etc.
          description = node.description or "";
          schema = node.schema or null;
          owner = node.owner or "";
          tags = node.tags or [];
        }) (config.nodes or {});
        
        # Edge definitions (transformations between nodes)
        edges = l.mapAttrs (source: targets: 
          l.map (target: {
            target = target.target;
            transformation = target.transformation or "unknown";
            description = target.description or "";
            pipeline = target.pipeline or null; # Reference to pipeline that performs this transformation
            timestamp = target.timestamp or null; # When this transformation was last run
          }) targets
        ) (config.edges or {});
        
        # Impact analysis (which nodes are affected by changes to a node)
        impactAnalysis = config.impactAnalysis or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk