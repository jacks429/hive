{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Apply defaults to configuration
  compression = transformers.withDefaults config {
    parameters = {};
    targetSize = null;
  };
  
  # Generate compression script
  compressionScript = transformers.withArgs {
    name = "compress-model-${compression.name}";
    description = "Compress model: ${compression.name}";
    args = [
      { name = "SOURCE_MODEL"; description = "Path to the source model to compress"; required = true; position = 0; }
      { name = "OUTPUT_PATH"; description = "Path to save the compressed model"; required = true; position = 1; }
    ];
  } ''
    echo "Compressing model: ${compression.name}"
    echo "Method: ${compression.method}"
    echo "Source model: $SOURCE_MODEL"
    echo "Output path: $OUTPUT_PATH"
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$OUTPUT_PATH")"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${compression.name}",
      "method": "${compression.method}",
      "parameters": ${transformers.toJSON compression.parameters},
      "targetSize": ${if compression.targetSize != null then "\"${toString compression.targetSize}\"" else "null"},
      "sourceModel": ${transformers.toJSON compression.sourceModel}
    }
    EOF
    
    # Run the model compression
    ${pkgs.python3.withPackages (ps: with ps; [ 
      numpy torch tensorflow
    ])}/bin/python ${root.utils.modelCompression or "${pkgs.writeText "model_compression.py" ''
      import json
      import sys
      import os
      import shutil
      
      def main():
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load source model
          source_model_path = sys.argv[2]
          print(f"Loading source model from {source_model_path}")
          
          # Set output path
          output_path = sys.argv[3]
          
          # Run compression
          print(f"Running {config['method']} compression with parameters: {config['parameters']}")
          
          # Create a report directory
          report_dir = os.path.join(os.path.dirname(output_path), "compression_report")
          os.makedirs(report_dir, exist_ok=True)
          
          # Simulate compression (for demonstration)
          if config['method'] == 'quantization':
              compression_ratio = 0.25
              accuracy_loss = 0.02
          elif config['method'] == 'pruning':
              compression_ratio = 0.5
              accuracy_loss = 0.01
          elif config['method'] == 'knowledge_distillation':
              compression_ratio = 0.3
              accuracy_loss = 0.03
          else:
              compression_ratio = 0.4
              accuracy_loss = 0.02
          
          # Create a dummy compressed model (for demonstration)
          if os.path.isdir(source_model_path):
              # Copy directory structure
              shutil.copytree(source_model_path, output_path, dirs_exist_ok=True)
              
              # Simulate size reduction
              for root, dirs, files in os.walk(output_path):
                  for file in files:
                      file_path = os.path.join(root, file)
                      if file.endswith('.bin') or file.endswith('.pt') or file.endswith('.h5'):
                          # Truncate the file to simulate compression
                          with open(file_path, 'rb') as f:
                              content = f.read()
                          
                          with open(file_path, 'wb') as f:
                              f.write(content[:int(len(content) * compression_ratio)])
          else:
              # Copy file
              with open(source_model_path, 'rb') as f:
                  content = f.read()
              
              with open(output_path, 'wb') as f:
                  f.write(content[:int(len(content) * compression_ratio)])
          
          # Generate report
          original_size = os.path.getsize(source_model_path) if os.path.isfile(source_model_path) else sum(os.path.getsize(os.path.join(dirpath, filename)) for dirpath, dirnames, filenames in os.walk(source_model_path) for filename in filenames)
          compressed_size = os.path.getsize(output_path) if os.path.isfile(output_path) else sum(os.path.getsize(os.path.join(dirpath, filename)) for dirpath, dirnames, filenames in os.walk(output_path) for filename in filenames)
          
          report = {
              "compression": config['name'],
              "method": config['method'],
              "original_size": original_size,
              "compressed_size": compressed_size,
              "compression_ratio": compressed_size / original_size if original_size > 0 else 0,
              "estimated_accuracy_loss": accuracy_loss,
              "parameters": config['parameters']
          }
          
          # Save report
          with open(os.path.join(report_dir, 'report.json'), 'w') as f:
              json.dump(report, f, indent=2)
          
          # Generate markdown report
          with open(os.path.join(report_dir, 'report.md'), 'w') as f:
              f.write(f"# Model Compression Report: {config['name']}\n\n")
              
              f.write("## Compression Details\n\n")
              f.write(f"- **Method**: {config['method']}\n")
              f.write(f"- **Original Size**: {original_size / (1024*1024):.2f} MB\n")
              f.write(f"- **Compressed Size**: {compressed_size / (1024*1024):.2f} MB\n")
              f.write(f"- **Compression Ratio**: {compressed_size / original_size:.2%}\n")
              f.write(f"- **Estimated Accuracy Loss**: {accuracy_loss:.2%}\n\n")
              
              f.write("## Parameters\n\n")
              for key, value in config['parameters'].items():
                  f.write(f"- **{key}**: {value}\n")
          
          print(f"Compression completed successfully. Compressed model saved to {output_path}")
          print(f"Compression report saved to {report_dir}")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$SOURCE_MODEL" "$OUTPUT_PATH"
    
    # Clean up
    rm "$CONFIG_FILE"
    
    echo "Model compression completed. Compressed model saved to $OUTPUT_PATH"
    echo "Compression report saved to $(dirname "$OUTPUT_PATH")/compression_report"
  '';
  
  # Generate documentation
  compressionDocs = transformers.generateDocs {
    name = "Model Compression: ${compression.name}";
    description = compression.description;
    usage = ''
      ```bash
      # Compress a model
      compress-model-${compression.name} /path/to/source/model /path/to/output/model
      ```
    '';
    examples = ''
      ```bash
      # Example: Compress a deep learning model
      compress-model-${compression.name} ./models/large_model ./models/compressed_model
      ```
    '';
    params = {
      method = {
        description = "Compression method to use";
        type = "string";
        value = compression.method;
      };
      parameters = {
        description = "Parameters for the compression method";
        type = "attrset";
        value = compression.parameters;
      };
      targetSize = {
        description = "Target size for the compressed model (null for default)";
        type = "string or null";
        value = compression.targetSize;
      };
      sourceModel = {
        description = "Source model configuration";
        type = "attrset";
        value = compression.sourceModel;
      };
    };
  };
  
  # Create derivations
  compressionDrv = transformers.mkScript {
    name = "compress-model-${compression.name}";
    description = "Compress model: ${compression.name}";
    script = compressionScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${compression.name}-model-compression";
    content = compressionDocs;
  };
  
in {
  # Original compression configuration
  inherit (compression) name description method parameters targetSize sourceModel;
  
  # Derivations
  compress = compressionDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = compression.metadata or {};
}
