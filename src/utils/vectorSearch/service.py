#!/usr/bin/env python3
import argparse
import json
import sys
import os
import glob
import numpy as np
from typing import List, Dict, Any, Optional
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

class QueryInput(BaseModel):
    query: str
    top_k: int = 5
    filter: Optional[Dict[str, Any]] = None

class QueryByVectorInput(BaseModel):
    vector: List[float]
    top_k: int = 5
    filter: Optional[Dict[str, Any]] = None

def load_vector_store(vector_dir: str) -> Dict[str, Any]:
    """Load vector store from directory."""
    # Load index file
    index_file = os.path.join(vector_dir, "index.json")
    if not os.path.exists(index_file):
        raise ValueError(f"Index file not found: {index_file}")
    
    with open(index_file, 'r') as f:
        index = json.load(f)
    
    # Load all document vectors
    documents = []
    vectors = []
    
    for doc_id in index.get("documents", []):
        doc_file = os.path.join(vector_dir, f"{doc_id}.json")
        if os.path.exists(doc_file):
            with open(doc_file, 'r') as f:
                doc = json.load(f)
                documents.append({
                    "id": doc["id"],
                    "content": doc["content"],
                    "metadata": doc["metadata"]
                })
                vectors.append(doc["embedding"])
    
    return {
        "index": index,
        "documents": documents,
        "vectors": np.array(vectors, dtype=np.float32)
    }

def create_app(vector_store: Dict[str, Any], embedder_config: Dict[str, Any]):
    app = FastAPI(
        title="Vector Search Service",
        description="API for semantic search using vector embeddings",
        version="1.0.0"
    )
    
    # Load embedder model
    embedder_type = embedder_config.get("type", "sentence-transformers")
    model_name = embedder_config.get("model", "all-MiniLM-L6-v2")
    
    if embedder_type == "sentence-transformers":
        try:
            from sentence_transformers import SentenceTransformer
            model = SentenceTransformer(model_name)
        except ImportError:
            print("Warning: sentence-transformers package not available")
            model = None
    else:
        print(f"Warning: Unsupported embedder type: {embedder_type}")
        model = None
    
    @app.post("/search")
    async def search(input_data: QueryInput):
        try:
            if model is None:
                raise HTTPException(status_code=500, detail="Embedding model not available")
            
            # Encode query
            query_embedding = model.encode(input_data.query)
            
            # Search
            return await search_by_vector(QueryByVectorInput(
                vector=query_embedding.tolist(),
                top_k=input_data.top_k,
                filter=input_data.filter
            ))
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.post("/search-by-vector")
    async def search_by_vector(input_data: QueryByVectorInput):
        try:
            # Convert query vector to numpy array
            query_vector = np.array(input_data.vector, dtype=np.float32)
            
            # Normalize query vector
            query_vector = query_vector / np.linalg.norm(query_vector)
            
            # Calculate cosine similarities
            similarities = np.dot(vector_store["vectors"], query_vector)
            
            # Get top k results
            top_k = min(input_data.top_k, len(vector_store["documents"]))
            top_indices = np.argsort(similarities)[::-1][:top_k]
            
            # Apply filter if provided
            if input_data.filter:
                filtered_indices = []
                for idx in top_indices:
                    doc = vector_store["documents"][idx]
                    if matches_filter(doc, input_data.filter):
                        filtered_indices.append(idx)
                top_indices = filtered_indices[:top_k]
            
            # Format results
            results = []
            for idx in top_indices:
                doc = vector_store["documents"][idx]
                results.append({
                    "id": doc["id"],
                    "content": doc["content"],
                    "metadata": doc["metadata"],
                    "score": float(similarities[idx])
                })
            
            return {"results": results}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.get("/info")
    async def get_info():
        return {
            "collection": vector_store["index"].get("collection", "default"),
            "count": len(vector_store["documents"]),
            "dimensions": vector_store["index"].get("dimensions", 0),
            "embedder": vector_store["index"].get("embedder", {}),
            "created_at": vector_store["index"].get("created_at", 0)
        }
    
    @app.get("/health")
    async def health():
        return {"status": "healthy"}
    
    return app

def matches_filter(doc: Dict[str, Any], filter_dict: Dict[str, Any]) -> bool:
    """Check if document matches the filter criteria."""
    for key, value in filter_dict.items():
        # Handle metadata fields
        if key.startswith("metadata."):
            metadata_key = key[9:]  # Remove "metadata." prefix
            if metadata_key not in doc["metadata"] or doc["metadata"][metadata_key] != value:
                return False
        # Handle direct fields
        elif key not in doc or doc[key] != value:
            return False
    
    return True

def main():
    parser = argparse.ArgumentParser(description="Vector search service")
    parser.add_argument("--vector-dir", required=True, help="Vector directory")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind")
    parser.add_argument("--embedder-model", default="all-MiniLM-L6-v2", help="Embedder model name")
    args = parser.parse_args()
    
    # Load vector store
    print(f"Loading vector store from {args.vector_dir}...")
    vector_store = load_vector_store(args.vector_dir)
    print(f"Loaded {len(vector_store['documents'])} documents with {vector_store['index'].get('dimensions', 0)} dimensions")
    
    # Get embedder config from index
    embedder_config = vector_store["index"].get("embedder", {
        "type": "sentence-transformers",
        "model": args.embedder_model
    })
    
    # Create FastAPI app
    app = create_app(vector_store, embedder_config)
    
    # Run server
    print(f"Starting vector search service on {args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port)

if __name__ == "__main__":
    main()