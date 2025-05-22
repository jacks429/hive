{
  inputs,
  cell,
}: {
  name = "text-classification";
  description = "Text classification pipeline using taxonomies";
  
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
      name = "preprocess-text";
      description = "Preprocess the text";
      command = ''
        nix run .#example-pipelines-text-preprocessing -- $INPUT_FILE $WORKSPACE/preprocessed.json
      '';
    }
    {
      name = "classify-text";
      description = "Classify text using news categories taxonomy";
      command = ''
        # First ensure the taxonomy is compiled
        nix run .#compile-taxonomy-news-categories
        
        # Then use it for classification
        nix run .#use-taxonomy-news-categories -- $WORKSPACE/preprocessed.json $WORKSPACE/classified.json
      '';
      depends = ["preprocess-text"];
    }
    {
      name = "format-output";
      description = "Format the final output";
      command = ''
        jq '.classification = .taxonomy | del(.taxonomy)' $WORKSPACE/classified.json > $OUTPUT_FILE
      '';
      depends = ["classify-text"];
    }
  ];
  
  # Resource requirements
  resources = {
    cpu = 2;
    memory = "2Gi";
  };
  
  # System information
  system = "x86_64-linux";
}