{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract lexicon configuration
  lexicon = config;
  
  # Helper function to read source file
  readSource = 
    if lexicon.source == null then ""
    else if builtins.isPath lexicon.source then builtins.readFile lexicon.source
    else if builtins.isString lexicon.source && builtins.substring 0 1 lexicon.source == "/" then builtins.readFile lexicon.source
    else lexicon.source; # Assume inline content
  
  # Process lexicon content based on format
  processedContent = 
    let
      rawContent = readSource;
    in
      if lexicon.format == "text" then
        # For text format, split by newlines and filter empty lines
        l.filter (line: line != "") (l.splitString "\n" rawContent)
      else if lexicon.format == "json" then
        # For JSON format, parse the JSON
        builtins.fromJSON rawContent
      else if lexicon.format == "csv" || lexicon.format == "tsv" then
        # For CSV/TSV format, split by newlines and then by delimiter
        let
          delimiter = if lexicon.format == "csv" then "," else "\t";
          lines = l.filter (line: line != "") (l.splitString "\n" rawContent);
          header = l.splitString delimiter (builtins.head lines);
          rows = map (line: l.splitString delimiter line) (builtins.tail lines);
        in
          map (row: builtins.listToAttrs (l.zipListsWith (name: value: { inherit name value; }) header row)) rows
      else
        # Default to raw content
        rawContent;
  
  # Apply normalization if requested
  normalizedContent =
    if !lexicon.normalize then
      processedContent
    else if builtins.isList processedContent then
      map (item: 
        if builtins.isString item then
          l.toLower item
        else
          item
      ) processedContent
    else
      processedContent;
  
  # Generate output content based on format
  outputContent =
    if lexicon.outputFormat == "text" && builtins.isList normalizedContent && builtins.all builtins.isString normalizedContent then
      builtins.concatStringsSep "\n" normalizedContent
    else if lexicon.outputFormat == "json" then
      builtins.toJSON normalizedContent
    else if lexicon.outputFormat == "trie" && builtins.isList normalizedContent && builtins.all builtins.isString normalizedContent then
      # Generate a simple trie structure for fast lookups
      let
        trie = builtins.foldl' (acc: word:
          let
            chars = l.stringToCharacters word;
            insertWord = node: remainingChars:
              if remainingChars == [] then
                node // { isWord = true; }
              else
                let
                  char = builtins.head remainingChars;
                  rest = builtins.tail remainingChars;
                  children = node.children or {};
                  childNode = children.${char} or { children = {}; isWord = false; };
                  updatedChild = insertWord childNode rest;
                in
                  node // {
                    children = children // {
                      ${char} = updatedChild;
                    };
                  };
          in
            insertWord acc chars
        ) { children = {}; isWord = false; } normalizedContent;
      in
        builtins.toJSON trie
    else
      # Default to the normalized content
      if builtins.isList normalizedContent && builtins.all builtins.isString normalizedContent then
        builtins.concatStringsSep "\n" normalizedContent
      else
        builtins.toJSON normalizedContent;
  
  # Create a derivation for the lexicon
  lexiconDrv = pkgs.writeTextFile {
    name = "lexicon-${lexicon.name}";
    text = outputContent;
    destination = "/share/lexicons/${lexicon.name}.${lexicon.outputFormat}";
  };
  
  # Generate a script to compile the lexicon
  compileLexiconScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Compiling lexicon: ${lexicon.name}"
    echo "Type: ${lexicon.type}"
    echo "Language: ${lexicon.language}"
    
    # Create output directory
    mkdir -p lexicons
    
    # Copy the lexicon file
    cp ${lexiconDrv}/share/lexicons/${lexicon.name}.${lexicon.outputFormat} lexicons/
    
    echo "Lexicon compiled to: lexicons/${lexicon.name}.${lexicon.outputFormat}"
  '';
  
  # Create a derivation for the compilation script
  compileLexiconScriptDrv = pkgs.writeScriptBin "compile-lexicon-${lexicon.name}" compileLexiconScript;
  
  # Generate a script to use the lexicon in a pipeline
  useLexiconScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [ $# -lt 1 ]; then
      echo "Usage: use-lexicon-${lexicon.name} INPUT_FILE [OUTPUT_FILE]"
      exit 1
    fi
    
    INPUT_FILE="$1"
    OUTPUT_FILE="''${2:-}"
    
    if [ -z "$OUTPUT_FILE" ]; then
      OUTPUT_FILE="''${INPUT_FILE%.*}.processed.''${INPUT_FILE##*.}"
    fi
    
    echo "Processing file with lexicon: ${lexicon.name}"
    echo "Input: $INPUT_FILE"
    echo "Output: $OUTPUT_FILE"
    
    # Ensure lexicon is available
    mkdir -p lexicons
    cp ${lexiconDrv}/share/lexicons/${lexicon.name}.${lexicon.outputFormat} lexicons/
    
    # Process the file based on lexicon type
    case "${lexicon.type}" in
      "stopwords")
        # Remove stopwords from input file
        if [ "${lexicon.outputFormat}" = "json" ]; then
          # Use jq to filter stopwords if input is JSON
          jq --slurpfile stopwords lexicons/${lexicon.name}.${lexicon.outputFormat} \
            'if type == "object" then . else . | split(" ") | map(select(. as $word | $stopwords[0] | index($word) | not)) | join(" ") end' \
            "$INPUT_FILE" > "$OUTPUT_FILE"
        else
          # Simple grep-based filtering for text files
          grep -v -f lexicons/${lexicon.name}.${lexicon.outputFormat} "$INPUT_FILE" > "$OUTPUT_FILE"
        fi
        ;;
      "gazetteer")
        # Highlight gazetteer entries in input file
        if [ "${lexicon.outputFormat}" = "json" ]; then
          # Use jq for JSON files
          jq --slurpfile gazetteer lexicons/${lexicon.name}.${lexicon.outputFormat} \
            'if type == "object" then . else . | split(" ") | map(if . as $word | $gazetteer[0] | index($word) then "<ENTITY>" + . + "</ENTITY>" else . end) | join(" ") end' \
            "$INPUT_FILE" > "$OUTPUT_FILE"
        else
          # Use sed for text files
          cp "$INPUT_FILE" "$OUTPUT_FILE"
          while IFS= read -r entity; do
            sed -i "s/\b$entity\b/<ENTITY>$entity<\/ENTITY>/g" "$OUTPUT_FILE"
          done < lexicons/${lexicon.name}.${lexicon.outputFormat}
        fi
        ;;
      "sentiment")
        # Apply sentiment scoring to input file
        if [ "${lexicon.outputFormat}" = "json" ]; then
          # Use jq for JSON files
          jq --slurpfile sentiment lexicons/${lexicon.name}.${lexicon.outputFormat} \
            'if type == "object" then . else . | split(" ") | map(. as $word | $sentiment[0] | if has($word) then {word: $word, sentiment: .[$word]} else {word: $word, sentiment: 0} end) end' \
            "$INPUT_FILE" > "$OUTPUT_FILE"
        else
          # Simple word-by-word scoring for text files
          python3 -c "
import sys
import json

# Load sentiment lexicon
sentiment = {}
with open('lexicons/${lexicon.name}.${lexicon.outputFormat}', 'r') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) >= 2:
            sentiment[parts[0]] = float(parts[1])

# Process input file
with open('$INPUT_FILE', 'r') as f:
    text = f.read()

words = text.split()
result = []
total_sentiment = 0

for word in words:
    word_sentiment = sentiment.get(word.lower(), 0)
    result.append({'word': word, 'sentiment': word_sentiment})
    total_sentiment += word_sentiment

# Write output
with open('$OUTPUT_FILE', 'w') as f:
    json.dump({
        'words': result,
        'total_sentiment': total_sentiment,
        'average_sentiment': total_sentiment / len(words) if words else 0
    }, f, indent=2)
          "
        fi
        ;;
      *)
        # Generic lexicon processing
        echo "Generic lexicon processing not implemented. Copying input to output."
        cp "$INPUT_FILE" "$OUTPUT_FILE"
        ;;
    esac
    
    echo "Processing complete."
  '';
  
  # Create a derivation for the usage script
  useLexiconScriptDrv = pkgs.writeScriptBin "use-lexicon-${lexicon.name}" useLexiconScript;
  
  # Generate documentation
  documentation = ''
    # Lexicon: ${lexicon.name}
    
    ${lexicon.description}
    
    ## Type
    
    This is a **${lexicon.type}** lexicon.
    
    ## Language
    
    Language: **${lexicon.language}**
    
    ## Format
    
    - Source format: ${lexicon.format}
    - Output format: ${lexicon.outputFormat}
    
    ## Processing Options
    
    - Case sensitive: ${if lexicon.caseSensitive then "Yes" else "No"}
    - Normalization: ${if lexicon.normalize then "Yes" else "No"}
    - Stemming: ${if lexicon.stemming then "Yes" else "No"}
    - Lemmatization: ${if lexicon.lemmatization then "Yes" else "No"}
    
    ## Usage
    
    ### Compile the lexicon
    
    ```bash
    nix run .#compile-lexicon-${lexicon.name}
    ```
    
    This will create the lexicon file at `lexicons/${lexicon.name}.${lexicon.outputFormat}`.
    
    ### Use the lexicon in a pipeline
    
    ```bash
    nix run .#use-lexicon-${lexicon.name} -- input.txt output.txt
    ```
    
    This will process `input.txt` using the lexicon and write the result to `output.txt`.
    
    ### Reference in a pipeline
    
    To reference this lexicon in a pipeline, use:
    
    ```nix
    {
      inputs,
      cell,
    }: {
      name = "my-nlp-pipeline";
      steps = [
        {
          name = "process-with-lexicon";
          command = "nix run .#use-lexicon-${lexicon.name} -- $INPUT_FILE $OUTPUT_FILE";
        }
      ];
    }
    ```
    
    Or access the lexicon file directly:
    
    ```nix
    {
      inputs,
      cell,
    }: {
      name = "my-nlp-pipeline";
      steps = [
        {
          name = "process-with-lexicon";
          command = "cat ${lexiconDrv}/share/lexicons/${lexicon.name}.${lexicon.outputFormat} | my-nlp-tool --lexicon-file=- $INPUT_FILE $OUTPUT_FILE";
        }
      ];
    }
    ```
  '';
  
  # Create a derivation for the documentation
  documentationDrv = pkgs.writeTextFile {
    name = "lexicon-${lexicon.name}-docs";
    text = documentation;
    destination = "/share/doc/lexicon-${lexicon.name}.md";
  };
  
  # Create a derivation that bundles everything together
  lexiconPackageDrv = pkgs.symlinkJoin {
    name = "lexicon-${lexicon.name}-package";
    paths = [
      lexiconDrv
      compileLexiconScriptDrv
      useLexiconScriptDrv
      documentationDrv
    ];
  };
  
in {
  # Original lexicon configuration
  inherit (lexicon) name description type language;
  inherit (lexicon) format outputFormat;
  inherit (lexicon) caseSensitive normalize stemming lemmatization;
  inherit (lexicon) system;
  
  # Processed content
  content = normalizedContent;
  
  # Derivations
  lexicon = lexiconDrv;
  compiler = compileLexiconScriptDrv;
  processor = useLexiconScriptDrv;
  docs = documentationDrv;
  package = lexiconPackageDrv;
  
  # Metadata
  metadata = {
    type = "lexicon";
    entryCount = if builtins.isList normalizedContent then builtins.length normalizedContent else 0;
  };
}