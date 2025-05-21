{
  inputs,
  cell,
}: {
  name = "bart-large-cnn";
  description = "BART model fine-tuned on CNN Daily Mail for summarization";
  system = "x86_64-linux";
  
  # Model information
  framework = "huggingface";
  modelUri = "facebook/bart-large-cnn";
  version = "1.0.0";
  task = "summarization";
  
  # Model parameters
  params = {
    max_length = {
      type = "int";
      default = 130;
      description = "Maximum length of the summary";
    };
    min_length = {
      type = "int";
      default = 30;
      description = "Minimum length of the summary";
    };
    do_sample = {
      type = "bool";
      default = false;
      description = "Whether to use sampling";
    };
  };
  
  # Service configuration (optional)
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8501;
  };
}