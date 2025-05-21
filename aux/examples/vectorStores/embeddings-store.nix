{
  inputs,
  cell,
}: {
  name = "embeddings-store";
  description = "Vector store for document embeddings";
  
  type = "qdrant";
  
  connection = {
    host = "localhost";
    port = 6333;
    grpc_port = 6334;
  };
  
  storage = {
    type = "file";
    path = "/var/lib/qdrant";
  };
  
  config = {
    max_vectors_per_collection = 1000000;
    max_collections = 100;
  };
  
  security = {
    enable = false;
    apiKey = null;
  };
  
  # System information
  system = "x86_64-linux";
}