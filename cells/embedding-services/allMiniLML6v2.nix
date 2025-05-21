{
  inputs,
  cell,
}: {
  modelUri = "sentence-transformers/all-MiniLM-L6-v2";
  framework = "sentence-transformers";
  params = {
    batch_size = 32;
    normalize_embeddings = true;
  };
  meta = {
    description = "Sentence-BERT embedding model that maps sentences & paragraphs to a 384 dimensional dense vector space";
    license = "Apache-2.0";
    tags = ["embeddings" "sentence-transformers" "semantic-search"];
    metrics = {
      stsb_spearman = 0.8113;
    };
    dimensions = 384;
  };
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8503;
  };
  system = "x86_64-linux";
}