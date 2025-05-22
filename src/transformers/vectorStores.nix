{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract store configuration
  store = config;
  
  # Generate Docker Compose configuration for the vector store
  generateDockerCompose = let
    composeConfig = 
      if store.type == "qdrant" then {
        version = "3";
        services.qdrant = {
          image = "qdrant/qdrant:${store.version}";
          ports = ["${toString store.connection.port}:6333" "6334:6334"];
          volumes = ["qdrant_data:/qdrant/storage"];
          environment = {
            QDRANT_HOST = "0.0.0.0";
          };
        };
        volumes.qdrant_data = {};
      }
      else if store.type == "weaviate" then {
        version = "3";
        services.weaviate = {
          image = "semitechnologies/weaviate:${store.version}";
          ports = ["${toString store.connection.port}:8080"];
          volumes = ["weaviate_data:/var/lib/weaviate"];
          environment = {
            AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED = "true";
            PERSISTENCE_DATA_PATH = "/var/lib/weaviate";
            DEFAULT_VECTORIZER_MODULE = "none";
            ENABLE_MODULES = "";
          };
        };
        volumes.weaviate_data = {};
      }
      else {
        version = "3";
        services.vector_db = {
          image = "custom/vector-db:latest";
          ports = ["${toString store.connection.port}:8000"];
          volumes = ["vector_db_data:/data"];
        };
        volumes.vector_db_data = {};
      };
  in
    pkgs.writeTextFile {
      name = "docker-compose-${store.name}";
      text = builtins.toJSON composeConfig;
      destination = "/share/vector-stores/${store.name}/docker-compose.json";
    };
  
  # Create a script to start the vector store
  startStoreScript = pkgs.writeShellScriptBin "start-vectorStore-${store.name}" ''
    COMPOSE_DIR="$PRJ_ROOT/vector-stores/${store.name}"
    mkdir -p "$COMPOSE_DIR"
    
    # Copy the docker-compose configuration
    cp ${generateDockerCompose}/share/vector-stores/${store.name}/docker-compose.json "$COMPOSE_DIR/docker-compose.json"
    
    # Convert JSON to YAML for docker-compose
    ${pkgs.yq}/bin/yq -P '.' "$COMPOSE_DIR/docker-compose.json" > "$COMPOSE_DIR/docker-compose.yml"
    
    # Start the vector store
    cd "$COMPOSE_DIR" && docker-compose up -d
    
    echo "Vector store ${store.name} started on ${store.connection.host}:${toString store.connection.port}"
  '';
  
  # Create a script to stop the vector store
  stopStoreScript = pkgs.writeShellScriptBin "stop-vectorStore-${store.name}" ''
    COMPOSE_DIR="$PRJ_ROOT/vector-stores/${store.name}"
    
    if [ -f "$COMPOSE_DIR/docker-compose.yml" ]; then
      cd "$COMPOSE_DIR" && docker-compose down
      echo "Vector store ${store.name} stopped"
    else
      echo "No docker-compose.yml found for vector store ${store.name}"
    fi
  '';
in {
  # Return the original configuration
  inherit (store) name description type version;
  inherit (store) connection resources;
  
  # Return the generated scripts
  start = startStoreScript;
  stop = stopStoreScript;
  dockerCompose = generateDockerCompose;
}
