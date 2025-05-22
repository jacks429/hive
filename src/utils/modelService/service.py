#!/usr/bin/env python3
import argparse
import json
import sys
import os
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, List, Optional

class TextInput(BaseModel):
    text: str
    params: Optional[Dict[str, Any]] = None

def create_app(model_uri, framework, modelType, config):
    app = FastAPI(
        title=f"{modelType.capitalize()} Service",
        description=f"API for {modelType} using {framework} framework",
        version="1.0.0"
    )
    
    # Load model based on framework
    if framework == "huggingface":
        from transformers import pipeline
        model_params = config.get("params", {})
        
        # Map modelType to Hugging Face pipeline task
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
        
        hf_task = task_mapping.get(modelType, modelType)
        model = pipeline(hf_task, model=model_uri)
    elif framework == "pytorch":
        import torch
        # Load PyTorch model
        # This is a simplified example
        model = torch.load(model_uri)
    elif framework == "tensorflow":
        import tensorflow as tf
        # Load TensorFlow model
        model = tf.saved_model.load(model_uri)
    elif framework == "onnx":
        import onnxruntime as ort
        # Load ONNX model
        model = ort.InferenceSession(model_uri)
    else:
        raise ValueError(f"Unsupported framework: {framework}")
    
    @app.post("/process")
    async def process(input_data: TextInput):
        try:
            # Merge default params with request params
            params = {**config.get("params", {}), **(input_data.params or {})}
            
            # Process with model based on modelType
            if modelType == "summarizers":
                result = model(input_data.text, **params)
                if isinstance(result, list):
                    return {"summary": result[0]["summary_text"]}
                return {"summary": result["summary_text"]}
            elif modelType == "sentimentAnalyzers":
                result = model(input_data.text, **params)
                return result
            # Add handlers for other modelTypes
            else:
                result = model(input_data.text, **params)
                return result
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.get("/health")
    async def health():
        return {"status": "healthy"}
    
    return app

def main():
    parser = argparse.ArgumentParser(description="Run model as a service")
    parser.add_argument("--model-uri", required=True, help="Model URI or path")
    parser.add_argument("--framework", required=True, help="Model framework")
    parser.add_argument("--modelType", required=True, help="Model type")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind")
    parser.add_argument("--config", required=True, help="Config file path")
    args = parser.parse_args()
    
    # Load config
    with open(args.config, 'r') as f:
        config = json.load(f)
    
    # Create FastAPI app
    app = create_app(args.model_uri, args.framework, args.modelType, config)
    
    # Run server
    uvicorn.run(app, host=args.host, port=args.port)

if __name__ == "__main__":
    main()
