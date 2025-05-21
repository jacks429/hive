{
  inputs,
  cell,
}: {
  name = "text-analysis";
  description = "NLP pipeline for text analysis using lexicons";
  
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
      name = "preprocess";
      description = "Preprocess text (lowercase, remove punctuation)";
      command = ''
        cat $INPUT_FILE | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' > $WORKSPACE/preprocessed.txt
      '';
    }
    {
      name = "remove-stopwords";
      description = "Remove stopwords using the English stopwords lexicon";
      command = ''
        nix run .#example-nlp-lexicons-stopwords-en-use -- $WORKSPACE/preprocessed.txt $WORKSPACE/no_stopwords.txt
      '';
      depends = ["preprocess"];
    }
    {
      name = "entity-recognition";
      description = "Recognize organization entities";
      command = ''
        nix run .#example-nlp-lexicons-entities-organizations-use -- $INPUT_FILE $WORKSPACE/entities.json
      '';
      depends = ["preprocess"];
    }
    {
      name = "sentiment-analysis";
      description = "Analyze sentiment using the sentiment lexicon";
      command = ''
        nix run .#example-nlp-lexicons-sentiment-en-use -- $WORKSPACE/no_stopwords.txt $WORKSPACE/sentiment.json
      '';
      depends = ["remove-stopwords"];
    }
    {
      name = "combine-results";
      description = "Combine all analysis results into a single output";
      command = ''
        jq -s '{
          entities: .[0],
          sentiment: .[1]
        }' $WORKSPACE/entities.json $WORKSPACE/sentiment.json > $OUTPUT_FILE
      '';
      depends = ["entity-recognition", "sentiment-analysis"];
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