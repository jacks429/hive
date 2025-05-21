{
  nixpkgs,
  root,
  inputs,
}: model: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${model.system};
  
  # Create a FastAPI service for the model
  serviceScript = ''
    #!/usr/bin/env python
    
    from fastapi import FastAPI, Request
    from pydantic import BaseModel
    import uvicorn
    import json
    
    app = FastAPI(title="${model.name} Service", 
                 description="${model.description or "NLP model service"}",
                 version="${model.version or "1.0.0"}")
    
    class TextInput(BaseModel):
        text: str
        ${l.concatStringsSep "\n    " (l.mapAttrsToList (name: type: 
          "${name}: ${type} = ${model.params.${name}.default or "None"}"
        ) (model.params or {}))}
    
    # Load model
    ${if model.framework == "huggingface" then ''
      from transformers import pipeline
      model = pipeline("${model.task}", model="${model.modelUri}")
    '' else if model.framework == "spacy" then ''
      import spacy
      nlp = spacy.load("${model.modelUri}")
    '' else ''
      # Custom model loading
      ${model.loadExpr or "# No custom load expression provided"}
    ''}
    
    @app.post("/process")
    async def process(input_data: TextInput):
        # Process with model
        ${if model.framework == "huggingface" then ''
          result = model(input_data.text)
        '' else if model.framework == "spacy" then ''
          doc = nlp(input_data.text)
          result = ${model.processExpr or "doc.to_json()"}
        '' else ''
          ${model.processExpr or "result = {'error': 'No process expression provided'}"}
        ''}
        
        return result
    
    @app.get("/info")
    async def info():
        return {
            "name": "${model.name}",
            "type": "${model.type}",
            "framework": "${model.framework}",
            "version": "${model.version or "1.0.0"}",
            "description": "${model.description or ""}",
            "parameters": ${l.toJSON (model.params or {})}
        }
    
    if __name__ == "__main__":
        uvicorn.run(app, host="${model.service.host or "0.0.0.0"}", port=${toString (model.service.port or 8000)})
  '';
  
  # Create a wrapper script
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting ${model.type} service: ${model.name} (${model.framework})"
    echo "Service will be available at http://${model.service.host or "0.0.0.0"}:${toString (model.service.port or 8000)}"
    
    ${pkgs.python3.withPackages (ps: with ps; [
      fastapi
      uvicorn
      pydantic
      (if model.framework == "huggingface" then transformers else null)
      (if model.framework == "spacy" then spacy else null)
    ])}/bin/python ${pkgs.writeText "serve-${model.name}.py" serviceScript}
  '';
  
  # Create service wrapper script derivation
  serviceDrv = pkgs.writeScriptBin "serve-${model.type}-${model.name}" wrapperScript;
  
in serviceDrv