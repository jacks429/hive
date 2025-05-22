{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "schemaEvolution";
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (target: config: {
        # Basic metadata
        name = config.name or "";
        description = config.description or "";
        version = config.version or "v1";
        
        # Target information
        target = config.target or "";
        
        # Migration scripts
        up = config.up or null;
        down = config.down or null;
        
        # Get system-specific packages
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Processed scripts with execution logic
        upScript = if config.up != null then ''
          ${nixpkgs.lib.readFile config.up}
        '' else "echo 'No up migration defined'";
        
        downScript = if config.down != null then ''
          ${nixpkgs.lib.readFile config.down}
        '' else "echo 'No down migration defined'";
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
    
  # Group migrations by target and sort by version
  migrationsByTarget = let
    allMigrations = walk inputs;
    targets = l.unique (map (m: m.target) (l.attrValues allMigrations));
  in
    l.genAttrs targets (target:
      l.sort (a: b: a.version < b.version)
        (l.filter (m: m.target == target) (l.attrValues allMigrations))
    );
in
  {
    migrations = walk inputs;
    migrationsByTarget = migrationsByTarget;
  }
