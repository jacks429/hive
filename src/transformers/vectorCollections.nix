{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract collection definition
  collection = {
    inherit (config) name description;
    dimensions = config.dimensions or 384;
    metric = config.metric or "cosine";
    store = config.store or "default";
    metadata-schema = config.metadata-schema or {};
  };
  
  # Generate JSON schema file
  schemaJson = pkgs.writeTextFile {
    name = "${collection.name}-schema.json";
    text = builtins.toJSON {
      name = collection.name;
      description = collection.description;
      dimensions = collection.dimensions;
      metric = collection.metric;
      store = collection.store;
      metadata-schema = collection.metadata-schema;
    };
  };
  
  # Generate markdown documentation
  docsMd = pkgs.writeTextFile {
    name = "${collection.name}-docs.md";
    text = ''
      # Vector Collection: ${collection.name}
      
      ${collection.description}
      
      ## Configuration
      
      - **Dimensions**: ${toString collection.dimensions}
      - **Distance Metric**: ${collection.metric}
      - **Vector Store**: ${collection.store}
      
      ## Metadata Schema
      
      ${if collection.metadata-schema != {} then ''
      | Field | Type | Description |
      |-------|------|-------------|
      ${l.concatMapStrings (field: let schema = collection.metadata-schema.${field}; in ''
      | ${field} | ${schema.type} | ${schema.description or ""} |
      '') (builtins.attrNames collection.metadata-schema)}
      '' else "No metadata schema defined."}
    '';
  };
  
  # Create a command to initialize the collection
  initScript = pkgs.writeShellScriptBin "init-collection-${collection.name}" ''
    #!/usr/bin/env bash
    
    echo "Initializing vector collection: ${collection.name}"
    echo "Dimensions: ${toString collection.dimensions}"
    echo "Distance Metric: ${collection.metric}"
    echo ""
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
      echo "Error: Python 3 is not installed."
      exit 1
    fi
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy the schema file
    cp ${schemaJson} $TEMP_DIR/schema.json
    
    # Create Python script to initialize the collection
    cat > $TEMP_DIR/init_collection.py << 'EOF'
    import json
    import os
    import sys
    
    try:
        import numpy as np
    except ImportError:
        print("Error: NumPy is not installed. Please install it with:")
        print("  pip install numpy")
        sys.exit(1)
    
    # Load schema
    with open('schema.json', 'r') as f:
        schema = json.load(f)
    
    # Determine the storage location
    if len(sys.argv) > 1:
        storage_dir = sys.argv[1]
    else:
        storage_dir = os.path.expanduser(f"~/.local/share/vector-store/{schema['name']}")
    
    # Create the directory if it doesn't exist
    os.makedirs(storage_dir, exist_ok=True)
    
    # Create the collection metadata file
    metadata_path = os.path.join(storage_dir, 'metadata.json')
    with open(metadata_path, 'w') as f:
        json.dump({
            'name': schema['name'],
            'description': schema['description'],
            'dimensions': schema['dimensions'],
            'metric': schema['metric'],
            'count': 0,
            'created_at': import datetime; datetime.datetime.now().isoformat(),
        }, f, indent=2)
    
    # Create empty vectors file
    vectors_path = os.path.join(storage_dir, 'vectors.npy')
    empty_vectors = np.zeros((0, schema['dimensions']), dtype=np.float32)
    np.save(vectors_path, empty_vectors)
    
    # Create empty metadata file
    items_path = os.path.join(storage_dir, 'items.json')
    with open(items_path, 'w') as f:
        json.dump([], f)
    
    print(f"Vector collection '{schema['name']}' initialized at: {storage_dir}")
    print(f"Dimensions: {schema['dimensions']}")
    print(f"Metric: {schema['metric']}")
    print("Ready for data ingestion.")
    EOF
    
    # Run the initialization script
    cd $TEMP_DIR
    python3 init_collection.py "$@"
  '';
  
in {
  # Original collection configuration
  inherit (collection) name description;
  inherit (collection) dimensions metric store;
  metadata-schema = collection.metadata-schema;
  
  # Derivations
  schema = schemaJson;
  documentation = docsMd;
  initialize = initScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
