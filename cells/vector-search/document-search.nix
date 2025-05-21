{
  inputs,
  cell,
}: {
  name = "document-search";
  description = "Search service for document embeddings";
  
  collection = "document-embeddings";
  vectorDir = "/var/lib/vector-store/document-embeddings";
  
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8600;
  };
  
  embedder = {
    type = "sentence-transformers";
    model = "all-MiniLM-L6-v2";
  };
  
  # System information
  system = "x86_64-linux";
}