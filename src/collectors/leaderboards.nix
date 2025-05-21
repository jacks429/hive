{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "leaderboards";
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
        task = config.task or "";
        
        # Metrics configuration
        primaryMetric = config.primaryMetric or "";
        metrics = config.metrics or [];
        sort = config.sort or "desc";
        
        # Display options
        displayOptions = config.displayOptions or {};
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk
