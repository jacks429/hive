{ inputs, nixpkgs, root }:
config: let
  l = nixpkgs.lib // builtins;

  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};

  # Convert config to JSON
  configJson = pkgs.writeTextFile {
    name = "vector-ingestor-config.json";
    text = l.toJSON {
      collection = config.collection;
      sources = config.sources;
      processors = config.processors;
      embedder = config.embedder;
    };
  };

  # Create runner script
  runnerScript = ''
    #!/usr/bin/env bash
    set -e

    echo "Running vector ingestor: ${config.name}"

    # Default output directory
    OUTPUT_DIR="${config.output-dir or "$HOME/.local/share/vector-store/${config.collection}"}"

    # Allow overriding output directory
    if [ $# -ge 1 ]; then
      OUTPUT_DIR="$1"
    fi

    echo "Output directory: $OUTPUT_DIR"

    # Run the ingestor
    ${pkgs.python3.withPackages (ps: with ps; [
      numpy sentence-transformers
    ])}/bin/python ${root.utils.vectorIngest}/ingestor.py \
      --config ${configJson} \
      --output-dir "$OUTPUT_DIR"
  '';

  # Create documentation
  documentation = ''
    # Vector Ingestor: ${config.name}

    ${config.description}

    ## Collection

    This ingestor creates the **${config.collection}** vector collection.

    ## Sources

    ${l.concatMapStrings (source: ''
    ### ${source.type} source

    ${if source.type == "file" then ''
    - Path: ${source.path}
    - Patterns: ${l.concatStringsSep ", " source.patterns}
    - Recursive: ${if source.recursive then "Yes" else "No"}
    '' else if source.type == "web" then ''
    - URLs: ${l.concatStringsSep ", " source.urls}
    - Depth: ${toString source.depth}
    '' else ''
    - Custom source type
    ''}

    '') config.sources}

    ## Processors

    ${l.concatMapStrings (processor: ''
    ### ${processor.type}

    ${if processor.type == "text_splitter" then ''
    - Chunk size: ${toString processor.chunk_size}
    - Chunk overlap: ${toString processor.chunk_overlap}
    '' else if processor.type == "metadata_extractor" then ''
    - Fields: ${l.concatStringsSep ", " processor.fields}
    '' else ''
    - Custom processor type
    ''}

    '') config.processors}

    ## Embedder

    - Type: ${config.embedder.type}
    - Model: ${config.embedder.model}
    - Batch size: ${toString config.embedder.batch_size}

    ## Usage

    ```bash
    # Run with default output directory
    nix run .#run-vectorIngestors-${config.name}

    # Run with custom output directory
    nix run .#run-vectorIngestors-${config.name} -- /path/to/output
    ```
  '';

  # Create derivations
  runnerDrv = pkgs.writeScriptBin "run-vectorIngestors-${config.name}" runnerScript;
  docsDrv = pkgs.writeTextFile {
    name = "vectorIngestors-${config.name}-docs";
    text = documentation;
    destination = "/share/doc/vectorIngestors-${config.name}.md";
  };

  # Create a derivation that bundles everything together
  packageDrv = pkgs.symlinkJoin {
    name = "vectorIngestors-${config.name}";
    paths = [ runnerDrv docsDrv ];
  };

in {
  # Original configuration
  inherit (config) name description collection;
  inherit (config) sources processors embedder system;

  # Derivations
  runner = runnerDrv;
  docs = docsDrv;
  package = packageDrv;
}