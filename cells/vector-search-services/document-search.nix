{
  inputs,
  cell,
}: {
  name = "document-search";
  description = "Search service for document embeddings";
  
  collection = "document-embeddings";
  vectorDir = "/var/lib/vector-store/document-embeddings";
  
  embedder = {
    model = "all-MiniLM-L6-v2";
  };
  
  service = {
    host = "0.0.0.0";
    port = 8600;
  };
  
  system = "x86_64-linux";
}