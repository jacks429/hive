#!/usr/bin/env python3
import argparse
import json
import sys
import os
import numpy as np
from typing import List, Dict, Any, Optional

def load_config(config_file: str) -> Dict[str, Any]:
    """Load configuration from file."""
    with open(config_file, 'r') as f:
        return json.load(f)

def encode_text(text: str, model_uri: str, params: Dict[str, Any]) -> List[float]:
    """Encode text to embedding vector."""
    try:
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer(model_uri)

        # Encode text
        embedding = model.encode(text, **params)

        # Normalize if requested
        if params.get("normalize_embeddings", False):
            embedding = embedding / np.linalg.norm(embedding)

        return embedding.tolist()
    except ImportError:
        print("Error: sentence-transformers package is required")
        raise ImportError("sentence-transformers package is required for text encoding")

def calculate_similarity(text1: str, text2: str, model_uri: str, params: Dict[str, Any]) -> float:
    """Calculate similarity between two texts."""
    # Encode both texts
    embedding1 = np.array(encode_text(text1, model_uri, params))
    embedding2 = np.array(encode_text(text2, model_uri, params))

    # Calculate cosine similarity
    similarity = np.dot(embedding1, embedding2) / (np.linalg.norm(embedding1) * np.linalg.norm(embedding2))

    return float(similarity)

def main():
    parser = argparse.ArgumentParser(description="Embedding service runner")
    parser.add_argument("--config", required=True, help="Configuration file")
    parser.add_argument("--mode", choices=["encode", "similarity"], required=True, help="Operation mode")
    parser.add_argument("--input", help="Input file or text")
    parser.add_argument("--input2", help="Second input file or text (for similarity mode)")
    parser.add_argument("--output", help="Output file (default: stdout)")
    args = parser.parse_args()

    # Load configuration
    config = load_config(args.config)
    model_uri = config.get("modelUri", "all-MiniLM-L6-v2")
    params = config.get("params", {})

    # Process based on mode
    if args.mode == "encode":
        # Get input text
        if args.input and os.path.isfile(args.input):
            with open(args.input, 'r', encoding='utf-8') as f:
                text = f.read()
        elif args.input:
            text = args.input
        else:
            text = sys.stdin.read()

        # Encode text
        embedding = encode_text(text, model_uri, params)

        # Output result
        result = {
            "text": text,
            "embedding": embedding,
            "dimensions": len(embedding)
        }

        if args.output:
            with open(args.output, 'w') as f:
                json.dump(result, f, indent=2)
        else:
            print(json.dumps(result, indent=2))

    elif args.mode == "similarity":
        # Get first input text
        if args.input and os.path.isfile(args.input):
            with open(args.input, 'r', encoding='utf-8') as f:
                text1 = f.read()
        elif args.input:
            text1 = args.input
        else:
            text1 = input("Enter first text: ")

        # Get second input text
        if args.input2 and os.path.isfile(args.input2):
            with open(args.input2, 'r', encoding='utf-8') as f:
                text2 = f.read()
        elif args.input2:
            text2 = args.input2
        else:
            text2 = input("Enter second text: ")

        # Calculate similarity
        similarity = calculate_similarity(text1, text2, model_uri, params)

        # Output result
        result = {
            "text1": text1,
            "text2": text2,
            "similarity": similarity
        }

        if args.output:
            with open(args.output, 'w') as f:
                json.dump(result, f, indent=2)
        else:
            print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
