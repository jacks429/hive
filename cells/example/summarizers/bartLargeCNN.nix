{
  inputs,
  cell,
}: {
  modelUri = "facebook/bart-large-cnn";
  framework = "huggingface";
  params = {
    max_length = 142;
    min_length = 56;
    length_penalty = 2.0;
    num_beams = 4;
    early_stopping = true;
  };
  meta = {
    description = "BART model fine-tuned on CNN Daily Mail for summarization";
    license = "MIT";
    tags = ["summarization" "news" "bart"];
    metrics = {
      rouge1 = 0.4387;
      rouge2 = 0.2136;
      rougeL = 0.3614;
    };
  };
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8501;
  };
  system = "x86_64-linux";
}