{
  inputs,
  cell,
}: {
  name = "text-preprocessing";
  description = "Text preprocessing pipeline using NLP rules";
  
  # Input and output configuration
  input = {
    type = "file";
    format = "text";
  };
  
  output = {
    type = "file";
    format = "json";
  };
  
  # Pipeline steps
  steps = [
    {
      name = "filter-noise";
      description = "Filter out noise from the text";
      command = ''
        nix run .#example-rules-noise-filtering-apply -- $INPUT_FILE $WORKSPACE/filtered.txt
      '';
    }
    {
      name = "normalize-text";
      description = "Normalize text (expand contractions, etc.)";
      command = ''
        nix run .#example-rules-text-normalization-apply -- $WORKSPACE/filtered.txt $WORKSPACE/normalized.txt
      '';
      depends = ["filter-noise"];
    }
    {
      name = "extract-emails";
      description = "Extract email addresses from text";
      command = ''
        nix run .#example-rules-email-regex-apply -- $WORKSPACE/normalized.txt $WORKSPACE/emails.json
      '';
      depends = ["normalize-text"];
    }
    {
      name = "tokenize-text";
      description = "Tokenize the text into words";
      command = ''
        nix run .#example-rules-word-tokenization-apply -- $WORKSPACE/normalized.txt $WORKSPACE/tokens.json
      '';
      depends = ["normalize-text"];
    }
    {
      name = "combine-results";
      description = "Combine all preprocessing results into a single output";
      command = ''
        jq -s '{
          emails: .[0],
          tokens: .[1]
        }' $WORKSPACE/emails.json $WORKSPACE/tokens.json > $OUTPUT_FILE
      '';
      depends = ["extract-emails" "tokenize-text"];
    }
  ];
  
  # Resource requirements
  resources = {
    cpu = 1;
    memory = "1Gi";
  };
  
  # System information
  system = "x86_64-linux";
}
