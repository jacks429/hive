{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "secretStores";
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
        
        # Backend configuration
        backend = config.backend or "sops";
        backendConfig = config.backendConfig or {};
        
        # Secrets
        secrets = config.secrets or [];
        
        # Access control
        accessControl = config.accessControl or {
          roles = [];
        };
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk
