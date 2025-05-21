#!/usr/bin/env python3
import argparse
import json
import sys
import os
import numpy as np

def main():
    parser = argparse.ArgumentParser(description="Run embedding models")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    parser.add_argument("--mode", default="encode", choices=["encode", "similarity"], help="Operation mode")
    args = parser.parse_args()
    
    # Load config
    with open(args.config, 'r') as f:
        config = json.load(f)
    
    # Load input
    with open(args.input, 'r') as f:
        input_text = f.read().strip()
    
    # Load model based on framework
    if config["framework"] == "sentence-transformers":
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer(args.model_uri)
    elif config["framework"] == "huggingface":
        from transformers import AutoModel, AutoTokenizer
        import torch
        
        # Load model and tokenizer
        tokenizer = AutoTokenizer.from_pretrained(args.model_uri)
        model = AutoModel.from_pretrained(args.model_uri)
        
        # Define encoding function
        def encode(texts, **kwargs):
            # Tokenize
            encoded_input = tokenizer(texts, padding=True, truncation=True, return_tensors='pt')
            
            # Compute token embeddings
            with torch.no_grad():
                model_output = model(**encoded_input)
            
            # Mean pooling
            attention_mask = encoded_input['attention_mask']
            token_embeddings = model_output[0]
            input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
            return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)
    else:
        raise ValueError(f"Unsupported framework: {config['framework']}")
    
    # Process based on mode
    if args.mode == "encode":
        # Split input into lines if multiple
        texts = [line for line in input_text.split('\n') if line.strip()]
        
        if config["framework"] == "sentence-transformers":
            embeddings = model.encode(texts, **config.get("params", {}))
        else:
            embeddings = encode(texts, **config.get("params", {})).numpy()
        
        # Convert to list for JSON serialization
        if isinstance(embeddings, np.ndarray):
            embeddings_list = embeddings.tolist()
        else:
            embeddings_list = [emb.tolist() if hasattr(emb, 'tolist') else emb for emb in embeddings]
        
        # Format output
        if len(texts) == 1:
            result = {"embedding": embeddings_list[0]}
        else:
            result = {"embeddings": embeddings_list}
    
    elif args.mode == "similarity":
        # Expect two texts separated by a tab
        if '\t' not in input_text:
            raise ValueError("For similarity mode, input should contain two texts separated by a tab")
        
        text1, text2 = input_text.split('\t', 1)
        
        if config["framework"] == "sentence-transformers":
            similarity = model.similarity(text1, text2, **config.get("params", {}))
            result = {"similarity": float(similarity)}
        else:
            # Manual similarity calculation
            emb1 = encode([text1], **config.get("params", {})).numpy()
            emb2 = encode([text2], **config.get("params", {})).numpy()
            
            # Cosine similarity
            similarity = np.dot(emb1[0], emb2[0]) / (np.linalg.norm(emb1[0]) * np.linalg.norm(emb2[0]))
            result = {"similarity": float(similarity)}
    
    # Write output
    with open(args.output, 'w') as f:
        json.dump(result, f, indent=2)

if __name__ == "__main__":
    main()