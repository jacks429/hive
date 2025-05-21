#!/usr/bin/env python3
import argparse
import json
import sys
import os
import glob
import hashlib
import time
from typing import List, Dict, Any, Optional
import numpy as np

def load_config(config_file: str) -> Dict[str, Any]:
    """Load configuration from file."""
    with open(config_file, 'r') as f:
        return json.load(f)

def process_file(file_path: str, processors: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Process a file through the processing pipeline."""
    # Read file content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Generate document ID
    doc_id = hashlib.md5(file_path.encode()).hexdigest()
    
    # Extract metadata
    metadata = {
        "source": os.path.basename(file_path),
        "path": file_path,
        "extension": os.path.splitext(file_path)[1],
        "size": os.path.getsize(file_path),
        "created": os.path.getctime(file_path),
        "modified": os.path.getmtime(file_path)
    }
    
    # Apply processors
    processed_content = content
    for processor in processors:
        processor_type = processor.get("type")
        
        if processor_type == "text_splitter":
            # Split text into chunks
            chunk_size = processor.get("chunk_size", 1000)
            chunk_overlap = processor.get("chunk_overlap", 200)
            # Simple implementation - split by newlines then recombine
            lines = processed_content.split('\n')
            chunks = []
            current_chunk = []
            current_size = 0
            
            for line in lines:
                line_size = len(line)
                if current_size + line_size > chunk_size and current_chunk:
                    chunks.append('\n'.join(current_chunk))
                    # Keep overlap
                    overlap_size = 0
                    overlap_chunk = []
                    while current_chunk and overlap_size < chunk_overlap:
                        line = current_chunk.pop()
                        overlap_chunk.insert(0, line)
                        overlap_size += len(line)
                    current_chunk = overlap_chunk
                    current_size = overlap_size
                
                current_chunk.append(line)
                current_size += line_size
            
            if current_chunk:
                chunks.append('\n'.join(current_chunk))
            
            # Create multiple documents
            return {
                "chunks": [
                    {
                        "id": f"{doc_id}-{i}",
                        "content": chunk,
                        "metadata": {
                            **metadata,
                            "chunk_index": i,
                            "chunk_count": len(chunks)
                        }
                    }
                    for i, chunk in enumerate(chunks)
                ]
            }
        
        elif processor_type == "metadata_extractor":
            # Extract additional metadata
            # This is a placeholder - in a real implementation, 
            # you would extract metadata based on file type
            pass
    
    # If no chunking was done, return single document
    return {
        "chunks": [
            {
                "id": doc_id,
                "content": processed_content,
                "metadata": metadata
            }
        ]
    }

def embed_documents(documents: List[Dict[str, Any]], embedder_config: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Embed documents using the specified embedder."""
    embedder_type = embedder_config.get("type", "sentence-transformers")
    model_name = embedder_config.get("model", "all-MiniLM-L6-v2")
    batch_size = embedder_config.get("batch_size", 32)
    
    if embedder_type == "sentence-transformers":
        try:
            from sentence_transformers import SentenceTransformer
            model = SentenceTransformer(model_name)
            
            # Prepare texts for embedding
            texts = [doc["content"] for doc in documents]
            
            # Generate embeddings in batches
            embeddings = []
            for i in range(0, len(texts), batch_size):
                batch_texts = texts[i:i+batch_size]
                batch_embeddings = model.encode(batch_texts)
                embeddings.extend(batch_embeddings)
            
            # Add embeddings to documents
            for i, doc in enumerate(documents):
                doc["embedding"] = embeddings[i].tolist()
            
            return documents
        except ImportError:
            print("Warning: sentence-transformers package not available")
            # Fallback to random embeddings for testing
            for doc in documents:
                doc["embedding"] = np.random.rand(384).tolist()  # Default embedding size
            return documents
    else:
        print(f"Warning: Unsupported embedder type: {embedder_type}")
        # Fallback to random embeddings for testing
        for doc in documents:
            doc["embedding"] = np.random.rand(384).tolist()  # Default embedding size
        return documents

def save_vector_store(documents: List[Dict[str, Any]], output_dir: str, collection: str, embedder_config: Dict[str, Any]) -> None:
    """Save documents and embeddings to vector store."""
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Create index file
    index = {
        "collection": collection,
        "created_at": int(time.time()),
        "documents": [doc["id"] for doc in documents],
        "dimensions": len(documents[0]["embedding"]) if documents else 0,
        "embedder": embedder_config
    }
    
    # Write index file
    with open(os.path.join(output_dir, "index.json"), 'w') as f:
        json.dump(index, f, indent=2)
    
    # Write document files
    for doc in documents:
        with open(os.path.join(output_dir, f"{doc['id']}.json"), 'w') as f:
            json.dump(doc, f, indent=2)
    
    print(f"Saved {len(documents)} documents to {output_dir}")

def main():
    parser = argparse.ArgumentParser(description="Vector ingestor")
    parser.add_argument("--config", required=True, help="Configuration file")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    args = parser.parse_args()
    
    # Load configuration
    config = load_config(args.config)
    
    # Process sources
    all_documents = []
    
    for source in config.get("sources", []):
        source_type = source.get("type")
        
        if source_type == "file":
            # Process files
            path = source.get("path", ".")
            patterns = source.get("patterns", ["*.txt"])
            recursive = source.get("recursive", False)
            
            for pattern in patterns:
                if recursive:
                    search_pattern = os.path.join(path, "**", pattern)
                    files = glob.glob(search_pattern, recursive=True)
                else:
                    search_pattern = os.path.join(path, pattern)
                    files = glob.glob(search_pattern)
                
                for file_path in files:
                    print(f"Processing file: {file_path}")
                    result = process_file(file_path, config.get("processors", []))
                    all_documents.extend(result["chunks"])
        
        elif source_type == "web":
            # Process web sources
            # This is a placeholder - in a real implementation, 
            # you would crawl web pages and extract content
            print(f"Web source processing not implemented: {source}")
    
    # Embed documents
    if all_documents:
        print(f"Embedding {len(all_documents)} documents...")
        embedded_documents = embed_documents(all_documents, config.get("embedder", {}))
        
        # Save to vector store
        save_vector_store(
            embedded_documents, 
            args.output_dir, 
            config.get("collection", "default"),
            config.get("embedder", {})
        )
    else:
        print("No documents found to process")

if __name__ == "__main__":
    main()