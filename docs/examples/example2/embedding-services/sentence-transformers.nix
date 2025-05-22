{
  inputs,
  cell,
}: {
  modelUri = "sentence-transformers/all-MiniLM-L6-v2";
  framework = "huggingface";
  params = {
    normalize_embeddings = true;
  };
  meta = {
    name = "sentence-transformers";
    description = "Sentence Transformers embedding model";
    license = "Apache-2.0";
    tags = ["embeddings" "sentence-transformers" "text"];
    dimensions = 384;
  };
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8500;
  };
  system = "x86_64-linux";
}