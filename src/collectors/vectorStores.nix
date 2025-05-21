{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "vectorStores";
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
        
        # Store type and configuration
        type = config.type or "qdrant"; # qdrant, pinecone, weaviate, etc.
        version = config.version or "latest";
        
        # Connection details
        connection = {
          host = config.connection.host or "localhost";
          port = config.connection.port or (
            if config.type == "qdrant" then 6333
            else if config.type == "weaviate" then 8080
            else 8000 # default fallback
          );
          apiKey = config.connection.apiKey or null;
          secure = config.connection.secure or false;
          environment = config.connection.environment or "production";
        };
        
        # Resource requirements
        resources = config.resources or {
          cpu = "1";
          memory = "2Gi";
          storage = "10Gi";
        };
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk