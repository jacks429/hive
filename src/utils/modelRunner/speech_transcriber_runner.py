#!/usr/bin/env python3
import argparse
import json
import sys
import os
import torch
from transformers import pipeline, AutoProcessor, AutoModelForSpeechSeq2Seq

def main():
    parser = argparse.ArgumentParser(description="Run speech transcription models")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--input", required=True, help="Input audio file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    args = parser.parse_args()
    
    # Load config
    with open(args.config, 'r') as f:
        config = json.load(f)
    
    # Load model
    device = "cuda" if torch.cuda.is_available() else "cpu"
    processor = AutoProcessor.from_pretrained(args.model_uri)
    model = AutoModelForSpeechSeq2Seq.from_pretrained(args.model_uri).to(device)
    
    # Create pipeline
    transcriber = pipeline(
        "automatic-speech-recognition",
        model=model,
        tokenizer=processor.tokenizer,
        feature_extractor=processor.feature_extractor,
        device=device,
    )
    
    # Process audio
    result = transcriber(args.input, **config.get("params", {}))
    
    # Write output
    with open(args.output, 'w') as f:
        if isinstance(result, dict) and "text" in result:
            f.write(result["text"])
        else:
            json.dump(result, f, indent=2)

if __name__ == "__main__":
    main()