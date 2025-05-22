#!/usr/bin/env python3
"""
Classifier model runner script.
"""

import argparse
import json
import os
import sys
from typing import Dict, Any

def parse_args():
    parser = argparse.ArgumentParser(description="Run a classifier model")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    return parser.parse_args()

def load_config(config_path: str) -> Dict[str, Any]:
    with open(config_path, 'r') as f:
        return json.load(f)

def run_huggingface_classifier(model_uri: str, input_path: str, output_path: str, params: Dict[str, Any]):
    try:
        from transformers import pipeline
        import torch
        
        # Load the input data
        with open(input_path, 'r') as f:
            text = f.read().strip()
        
        # Create the classifier pipeline
        classifier = pipeline("text-classification", model=model_uri, **params)
        
        # Run classification
        result = classifier(text)
        
        # Write output
        with open(output_path, 'w') as f:
            json.dump(result, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running classifier: {e}", file=sys.stderr)
        sys.exit(1)

def run_sklearn_classifier(model_uri: str, input_path: str, output_path: str, params: Dict[str, Any]):
    try:
        import numpy as np
        import pickle
        
        # Load the model
        with open(model_uri, 'rb') as f:
            model = pickle.load(f)
        
        # Load the input data
        with open(input_path, 'r') as f:
            data = json.load(f)
        
        # Convert to numpy array if needed
        if isinstance(data, list):
            data = np.array(data)
        
        # Run prediction
        predictions = model.predict(data)
        probabilities = None
        if hasattr(model, 'predict_proba'):
            probabilities = model.predict_proba(data).tolist()
        
        # Write output
        with open(output_path, 'w') as f:
            result = {
                "predictions": predictions.tolist() if isinstance(predictions, np.ndarray) else predictions,
                "probabilities": probabilities
            }
            json.dump(result, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running classifier: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    args = parse_args()
    config = load_config(args.config)
    
    framework = config.get("framework", "huggingface").lower()
    params = config.get("params", {})
    
    if framework == "huggingface":
        run_huggingface_classifier(args.model_uri, args.input, args.output, params)
    elif framework == "sklearn":
        run_sklearn_classifier(args.model_uri, args.input, args.output, params)
    else:
        print(f"Error: Unsupported framework '{framework}'", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()