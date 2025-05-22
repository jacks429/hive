#!/usr/bin/env python3
import argparse
import json
import sys
import os
from transformers import pipeline

def parse_args():
    parser = argparse.ArgumentParser(description="Run a Hugging Face model")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--task", required=True, help="Task type (e.g., summarizers, sentimentAnalyzers)")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--config", required=True, help="Config file path")
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Load config
    with open(args.config, 'r') as f:
        config = json.load(f)
    
    # Load input text
    with open(args.input, 'r') as f:
        input_text = f.read().strip()
    
    # Map task to Hugging Face pipeline task
    task_mapping = {
        "summarizers": "summarization",
        "sentimentAnalyzers": "sentiment-analysis",
        "topicModels": "text-classification",
        "translationModels": "translation",
        "languageDetectors": "text-classification",
        "textGenerators": "text-generation",
        "paraphrasers": "text2text-generation",
        "simplifiers": "text2text-generation",
        "qaSystems": "question-answering",
        # Add mappings for other tasks
    }
    
    hf_task = task_mapping.get(args.task, args.task)
    
    # Initialize model
    model = pipeline(hf_task, model=args.model_uri)
    
    # Process input based on task
    if args.task == "summarizers":
        result = model(input_text, **config.get("params", {}))
        output = result[0]["summary_text"] if isinstance(result, list) else result["summary_text"]
    elif args.task == "sentimentAnalyzers":
        result = model(input_text, **config.get("params", {}))
        output = json.dumps(result, indent=2)
    # Add handlers for other tasks
    else:
        result = model(input_text, **config.get("params", {}))
        output = json.dumps(result, indent=2)
    
    # Write output
    with open(args.output, 'w') as f:
        f.write(output)

if __name__ == "__main__":
    main()
