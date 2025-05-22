#!/usr/bin/env python3
"""
Embedding model runner script.
"""

import argparse
import json
import os
import sys
from typing import Dict, Any, List, Union

def parse_args():
    parser = argparse.ArgumentParser(description="Run an embedding model")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    parser.add_argument("--mode", default="encode", choices=["encode", "similarity"], 
                        help="Operation mode: encode or similarity")
    return parser.parse_args()

def load_config(config_path: str) -> Dict[str, Any]:
    with open(config_path, 'r') as f:
        return json.load(f)

def run_sentence_transformers(model_uri: str, input_path: str, output_path: str, 
                             params: Dict[str, Any], mode: str):
    try:
        from sentence_transformers import SentenceTransformer, util
        import torch
        import numpy as np
        
        # Load the model
        model = SentenceTransformer(model_uri)
        
        # Load the input data
        with open(input_path, 'r') as f:
            content = f.read().strip()
            
            # Try to parse as JSON if possible
            try:
                data = json.loads(content)
            except json.JSONDecodeError:
                # If not JSON, treat as plain text
                if mode == "encode":
                    # Split by lines for encoding
                    data = [line for line in content.split('\n') if line.strip()]
                else:
                    # For similarity, expect two texts
                    data = [content, content]  # Default to same text
        
        # Process based on mode
        if mode == "encode":
            # Handle different input formats
            texts_to_encode = []
            if isinstance(data, list):
                texts_to_encode = data
            elif isinstance(data, dict) and "texts" in data:
                texts_to_encode = data["texts"]
            elif isinstance(data, dict) and "text" in data:
                texts_to_encode = [data["text"]]
            else:
                texts_to_encode = [str(data)]
            
            # Encode the texts
            batch_size = params.get("batch_size", 32)
            embeddings = model.encode(texts_to_encode, batch_size=batch_size)
            
            # Convert to list for JSON serialization
            embeddings_list = embeddings.tolist()
            
            # Write output
            with open(output_path, 'w') as f:
                json.dump({
                    "embeddings": embeddings_list,
                    "dimensions": len(embeddings_list[0]) if embeddings_list else 0
                }, f, indent=2)
                
        elif mode == "similarity":
            # Handle different input formats for similarity
            text1, text2 = "", ""
            if isinstance(data, list) and len(data) >= 2:
                text1, text2 = data[0], data[1]
            elif isinstance(data, dict) and "text1" in data and "text2" in data:
                text1, text2 = data["text1"], data["text2"]
            
            # Encode both texts
            embedding1 = model.encode(text1, convert_to_tensor=True)
            embedding2 = model.encode(text2, convert_to_tensor=True)
            
            # Calculate similarity
            similarity = util.pytorch_cos_sim(embedding1, embedding2).item()
            
            # Write output
            with open(output_path, 'w') as f:
                json.dump({
                    "text1": text1,
                    "text2": text2,
                    "similarity": similarity
                }, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running embedding model: {e}", file=sys.stderr)
        sys.exit(1)

def run_huggingface_embeddings(model_uri: str, input_path: str, output_path: str, 
                              params: Dict[str, Any], mode: str):
    try:
        from transformers import AutoTokenizer, AutoModel
        import torch
        import numpy as np
        
        # Load the model and tokenizer
        tokenizer = AutoTokenizer.from_pretrained(model_uri)
        model = AutoModel.from_pretrained(model_uri)
        
        # Load the input data
        with open(input_path, 'r') as f:
            content = f.read().strip()
            
            # Try to parse as JSON if possible
            try:
                data = json.loads(content)
            except json.JSONDecodeError:
                # If not JSON, treat as plain text
                if mode == "encode":
                    # Split by lines for encoding
                    data = [line for line in content.split('\n') if line.strip()]
                else:
                    # For similarity, expect two texts
                    data = [content, content]  # Default to same text
        
        # Helper function to get embeddings
        def get_embedding(text):
            # Tokenize and get model output
            inputs = tokenizer(text, return_tensors="pt", padding=True, truncation=True, 
                              max_length=params.get("max_length", 512))
            with torch.no_grad():
                outputs = model(**inputs)
            
            # Use mean of last hidden states as embedding
            embedding = outputs.last_hidden_state.mean(dim=1).squeeze().numpy()
            return embedding
        
        # Process based on mode
        if mode == "encode":
            # Handle different input formats
            texts_to_encode = []
            if isinstance(data, list):
                texts_to_encode = data
            elif isinstance(data, dict) and "texts" in data:
                texts_to_encode = data["texts"]
            elif isinstance(data, dict) and "text" in data:
                texts_to_encode = [data["text"]]
            else:
                texts_to_encode = [str(data)]
            
            # Encode the texts
            embeddings = [get_embedding(text).tolist() for text in texts_to_encode]
            
            # Write output
            with open(output_path, 'w') as f:
                json.dump({
                    "embeddings": embeddings,
                    "dimensions": len(embeddings[0]) if embeddings else 0
                }, f, indent=2)
                
        elif mode == "similarity":
            # Handle different input formats for similarity
            text1, text2 = "", ""
            if isinstance(data, list) and len(data) >= 2:
                text1, text2 = data[0], data[1]
            elif isinstance(data, dict) and "text1" in data and "text2" in data:
                text1, text2 = data["text1"], data["text2"]
            
            # Encode both texts
            embedding1 = get_embedding(text1)
            embedding2 = get_embedding(text2)
            
            # Calculate cosine similarity
            similarity = np.dot(embedding1, embedding2) / (np.linalg.norm(embedding1) * np.linalg.norm(embedding2))
            
            # Write output
            with open(output_path, 'w') as f:
                json.dump({
                    "text1": text1,
                    "text2": text2,
                    "similarity": float(similarity)
                }, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running embedding model: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    args = parse_args()
    config = load_config(args.config)
    
    framework = config.get("framework", "sentence-transformers").lower()
    params = config.get("params", {})
    
    if framework == "sentence-transformers":
        run_sentence_transformers(args.model_uri, args.input, args.output, params, args.mode)
    elif framework == "huggingface":
        run_huggingface_embeddings(args.model_uri, args.input, args.output, params, args.mode)
    else:
        print(f"Error: Unsupported framework '{framework}'", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
