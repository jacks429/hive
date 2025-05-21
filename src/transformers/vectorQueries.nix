{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract query definition
  query = {
    inherit (config) name description;
    collection = config.collection or "";
    filters = config.filters or [];
    top-k = config.top-k or 10;
    embedder = config.embedder or {
      type = "sentence-transformers";
      model = "all-MiniLM-L6-v2";
    };
  };
  
  # Generate JSON query file
  queryJson = pkgs.writeTextFile {
    name = "${query.name}-query.json";
    text = builtins.toJSON {
      name = query.name;
      description = query.description;
      collection = query.collection;
      filters = query.filters;
      top-k = query.top-k;
      embedder = query.embedder;
    };
  };
  
  # Generate markdown documentation
  docsMd = pkgs.writeTextFile {
    name = "${query.name}-docs.md";
    text = ''
      # Vector Query: ${query.name}
      
      ${query.description}
      
      ## Configuration
      
      - **Collection**: ${query.collection}
      - **Top K Results**: ${toString query.top-k}
      
      ## Embedder
      
      - **Type**: ${query.embedder.type}
      - **Model**: ${query.embedder.model}
      
      ## Filters
      
      ${if query.filters != [] then ''
      | Field | Operator | Value |
      |-------|----------|-------|
      ${l.concatMapStrings (filter: ''
      | ${filter.field} | ${filter.operator} | ${
        if builtins.isString filter.value 
        then filter.value 
        else builtins.toJSON filter.value
      } |
      '') query.filters}
      '' else "No filters defined."}
    '';
  };
  
  # Create a command to run the query
  runScript = pkgs.writeShellScriptBin "run-query-${query.name}" ''
    #!/usr/bin/env bash
    
    if [ $# -lt 1 ]; then
      echo "Usage: run-query-${query.name} QUERY_TEXT [COLLECTION_PATH]"
      echo "Example: run-query-${query.name} 'What is machine learning?'"
      exit 1
    fi
    
    QUERY_TEXT="$1"
    COLLECTION_PATH="$2"
    
    echo "Running vector query: ${query.name}"
    echo "Query text: $QUERY_TEXT"
    echo "Collection: ${query.collection}"
    echo ""
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
      echo "Error: Python 3 is not installed."
      exit 1
    fi
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy the query file
    cp ${queryJson} $TEMP_DIR/query.json
    
    # Create Python script to run the query
    cat > $TEMP_DIR/run_query.py << 'EOF'
    import json
    import os
    import sys
    
    try:
        import numpy as np
        from sentence_transformers import SentenceTransformer
    except ImportError:
        print("Error: Required packages not installed. Please install them with:")
        print("  pip install numpy sentence-transformers")
        sys.exit(1)
    
    # Load query configuration
    with open('query.json', 'r') as f:
        query_config = json.load(f)
    
    # Get query text from command line
    if len(sys.argv) < 2:
        print("Error: Query text is required")
        sys.exit(1)
    
    query_text = sys.argv[1]
    
    # Determine collection path
    if len(sys.argv) > 2:
        collection_path = sys.argv[2]
    else:
        collection_path = os.path.expanduser(f"~/.local/share/vector-store/{query_config['collection']}")
    
    # Check if collection exists
    if not os.path.exists(collection_path):
        print(f"Error: Collection not found at {collection_path}")
        sys.exit(1)
    
    # Load collection metadata
    metadata_path = os.path.join(collection_path, 'metadata.json')
    with open(metadata_path, 'r') as f:
        collection_metadata = json.load(f)
    
    # Load vectors
    vectors_path = os.path.join(collection_path, 'vectors.npy')
    if not os.path.exists(vectors_path):
        print(f"Error: Vectors file not found at {vectors_path}")
        sys.exit(1)
    
    vectors = np.load(vectors_path)
    
    # Load items metadata
    items_path = os.path.join(collection_path, 'items.json')
    with open(items_path, 'r') as f:
        items = json.load(f)
    
    # Check if collection is empty
    if len(items) == 0:
        print("Collection is empty. No results to return.")
        sys.exit(0)
    
    # Load embedder model
    embedder_type = query_config['embedder']['type']
    embedder_model = query_config['embedder']['model']
    
    if embedder_type == 'sentence-transformers':
        model = SentenceTransformer(embedder_model)
    else:
        print(f"Error: Unsupported embedder type: {embedder_type}")
        sys.exit(1)
    
    # Encode query text
    query_embedding = model.encode(query_text)
    
    # Apply filters
    filtered_indices = list(range(len(items)))
    for filter_config in query_config['filters']:
        field = filter_config['field']
        operator = filter_config['operator']
        value = filter_config['value']
        
        filtered_indices = [
            i for i in filtered_indices
            if field in items[i]['metadata'] and
            (
                (operator == 'eq' and items[i]['metadata'][field] == value) or
                (operator == 'neq' and items[i]['metadata'][field] != value) or
                (operator == 'gt' and items[i]['metadata'][field] > value) or
                (operator == 'gte' and items[i]['metadata'][field] >= value) or
                (operator == 'lt' and items[i]['metadata'][field] < value) or
                (operator == 'lte' and items[i]['metadata'][field] <= value) or
                (operator == 'contains' and value in items[i]['metadata'][field]) or
                (operator == 'in' and items[i]['metadata'][field] in value)
            )
        ]
    
    # If no items match the filters, return empty results
    if not filtered_indices:
        print("No items match the specified filters.")
        sys.exit(0)
    
    # Get filtered vectors
    filtered_vectors = vectors[filtered_indices]
    
    # Calculate similarities
    if collection_metadata['metric'] == 'cosine':
        # Normalize query embedding for cosine similarity
        query_embedding = query_embedding / np.linalg.norm(query_embedding)
        # Normalize vectors for cosine similarity (assuming they're already normalized)
        similarities = np.dot(filtered_vectors, query_embedding)
    elif collection_metadata['metric'] == 'euclidean':
        # Calculate negative euclidean distance (higher is better)
        similarities = -np.linalg.norm(filtered_vectors - query_embedding, axis=1)
    elif collection_metadata['metric'] == 'dot':
        # Calculate dot product
        similarities = np.dot(filtered_vectors, query_embedding)
    else:
        print(f"Error: Unsupported distance metric: {collection_metadata['metric']}")
        sys.exit(1)
    
    # Get top-k results
    top_k = min(query_config['top-k'], len(filtered_indices))
    top_indices = np.argsort(similarities)[-top_k:][::-1]
    
    # Prepare results
    results = []
    for i, idx in enumerate(top_indices):
        original_idx = filtered_indices[idx]
        item = items[original_idx]
        results.append({
            'id': item['id'],
            'score': float(similarities[idx]),
            'metadata': item['metadata'],
            'text': item['text'],
            'rank': i + 1
        })
    
    # Print results
    print(f"Found {len(results)} results for query: '{query_text}'")
    print("")
    for result in results:
        print(f"Rank {result['rank']} (Score: {result['score']:.4f}):")
        print(f"ID: {result['id']}")
        print(f"Text: {result['text'][:100]}...")
        print("Metadata:", json.dumps(result['metadata'], indent=2))
        print("")
    
    # Save results to file
    with open('results.json', 'w') as f:
        json.dump({
            'query': query_text,
            'results': results
        }, f, indent=2)
    
    print(f"Results saved to {os.path.join(os.getcwd(), 'results.json')}")
    EOF
    
    # Run the query script
    cd $TEMP_DIR
    python3 run_query.py "$QUERY_TEXT" "$COLLECTION_PATH"
  '';
  
in {
  # Original query configuration
  inherit (query) name description;
  inherit (query) collection filters top-k embedder;
  
  # Derivations
  json = queryJson;
  documentation = docsMd;
  run = runScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
