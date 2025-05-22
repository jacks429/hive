#!/usr/bin/env python3
"""
Sentiment analyzer model runner script.
"""

import argparse
import json
import os
import sys
from typing import Dict, Any

def parse_args():
    parser = argparse.ArgumentParser(description="Run a sentiment analyzer model")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    return parser.parse_args()

def load_config(config_path: str) -> Dict[str, Any]:
    with open(config_path, 'r') as f:
        return json.load(f)

def run_huggingface_sentiment(model_uri: str, input_path: str, output_path: str, params: Dict[str, Any]):
    try:
        from transformers import pipeline
        import torch
        
        # Load the input data
        with open(input_path, 'r') as f:
            content = f.read().strip()
            
            # Try to parse as JSON if possible
            try:
                data = json.loads(content)
                # Extract text from JSON if needed
                if isinstance(data, dict) and "text" in data:
                    text = data["text"]
                elif isinstance(data, list):
                    text = data  # Assume list of texts
                else:
                    text = str(data)
            except json.JSONDecodeError:
                # If not JSON, treat as plain text
                text = content
        
        # Create the sentiment analysis pipeline
        sentiment_analyzer = pipeline("sentiment-analysis", model=model_uri, **params)
        
        # Run sentiment analysis
        if isinstance(text, list):
            result = sentiment_analyzer(text)
        else:
            result = sentiment_analyzer(text)
        
        # Write output
        with open(output_path, 'w') as f:
            json.dump(result, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running sentiment analyzer: {e}", file=sys.stderr)
        sys.exit(1)

def run_vader_sentiment(input_path: str, output_path: str, params: Dict[str, Any]):
    try:
        from nltk.sentiment.vader import SentimentIntensityAnalyzer
        import nltk
        
        # Download VADER lexicon if needed
        try:
            nltk.data.find('sentiment/vader_lexicon.zip')
        except LookupError:
            nltk.download('vader_lexicon')
        
        # Load the input data
        with open(input_path, 'r') as f:
            content = f.read().strip()
            
            # Try to parse as JSON if possible
            try:
                data = json.loads(content)
                # Extract text from JSON if needed
                if isinstance(data, dict) and "text" in data:
                    text = data["text"]
                elif isinstance(data, list):
                    text = data  # Assume list of texts
                else:
                    text = str(data)
            except json.JSONDecodeError:
                # If not JSON, treat as plain text
                text = content
        
        # Initialize the sentiment analyzer
        sid = SentimentIntensityAnalyzer()
        
        # Run sentiment analysis
        if isinstance(text, list):
            result = [sid.polarity_scores(t) for t in text]
        else:
            result = sid.polarity_scores(text)
        
        # Write output
        with open(output_path, 'w') as f:
            json.dump(result, f, indent=2)
            
    except ImportError as e:
        print(f"Error: Required libraries not available: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error running sentiment analyzer: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    args = parse_args()
    config = load_config(args.config)
    
    framework = config.get("framework", "huggingface").lower()
    params = config.get("params", {})
    
    if framework == "huggingface":
        run_huggingface_sentiment(args.model_uri, args.input, args.output, params)
    elif framework == "vader":
        run_vader_sentiment(args.input, args.output, params)
    else:
        print(f"Error: Unsupported framework '{framework}'", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()