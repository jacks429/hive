#!/usr/bin/env python3
"""
Deep learning model runner script.
"""

import argparse
import json
import os
import sys
from typing import Dict, Any

def parse_args():
    parser = argparse.ArgumentParser(description="Run a deep learning model")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--framework", required=True, choices=["pytorch", "tensorflow", "huggingface"],
                        help="Deep learning framework")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    return parser.parse_args()

def load_config(config_path: str) -> Dict[str, Any]:
    with open(config_path, 'r') as f:
        return json.load(f)

def run_pytorch_model(model_uri: str, input_path: str, output_path: str, config: Dict[str, Any]):
    try:
        import torch
        import numpy as np
        
        # Load the model
        model = torch.load(model_uri)
        model.eval()
        
        # Load the input data
        with open(input_path, 'r') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                # If not JSON, try to load as raw text
                f.seek(0)
                data = f.read().strip()
        
        # Convert input to tensor
        if isinstance(data, list):
            input_tensor = torch.tensor(data, dtype=torch.float32)
        elif isinstance(data, dict) and "input" in data:
            input_tensor = torch.tensor(data["input"], dtype=torch.float32)
        else:
            # For text input, tokenize or process as needed
            # This is a simplified example
            input_tensor = torch.tensor([ord(c) for c in data[:100]], dtype=torch.float32)
        
        # Run inference
        with torch.no_grad():
            output = model(input_tensor)
        
        # Convert output to list for JSON serialization
        if isinstance(output, torch.Tensor):
            output_data = output.numpy().tolist()
        else:
            output_data = output
        
        # Write output
        with open(output_path, 'w') as f:
            json.dump({"output": output_data}, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running PyTorch model: {e}", file=sys.stderr)
        sys.exit(1)

def run_tensorflow_model(model_uri: str, input_path: str, output_path: str, config: Dict[str, Any]):
    try:
        import tensorflow as tf
        import numpy as np
        
        # Load the model
        model = tf.keras.models.load_model(model_uri)
        
        # Load the input data
        with open(input_path, 'r') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                # If not JSON, try to load as raw text
                f.seek(0)
                data = f.read().strip()
        
        # Convert input to numpy array
        if isinstance(data, list):
            input_array = np.array(data)
        elif isinstance(data, dict) and "input" in data:
            input_array = np.array(data["input"])
        else:
            # For text input, tokenize or process as needed
            # This is a simplified example
            input_array = np.array([[ord(c) for c in data[:100]]])
        
        # Run inference
        output = model.predict(input_array)
        
        # Convert output to list for JSON serialization
        output_data = output.tolist()
        
        # Write output
        with open(output_path, 'w') as f:
            json.dump({"output": output_data}, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running TensorFlow model: {e}", file=sys.stderr)
        sys.exit(1)

def run_huggingface_model(model_uri: str, input_path: str, output_path: str, config: Dict[str, Any]):
    try:
        from transformers import AutoTokenizer, AutoModel, pipeline
        import torch
        