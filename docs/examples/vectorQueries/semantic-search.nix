{
  inputs,
  cell,
}: {
  name = "semantic-search";
  description = "Semantic search for documents";
  
  collection = "document-embeddings";
  
  embedder = {
    type = "sentence-transformers";
    model = "all-MiniLM-L6-v2";
  };
  
  search = {
    limit = 10;
    threshold = 0.7;
    filters = [
      {
        field = "tags";
        condition = "contains";
        value = "documentation";
      }
    ];
  };
  
  reranker = {
    enable = true;
    type = "cross-encoder";
    model = "cross-encoder/ms-marco-MiniLM-L-6-v2";
  };
  
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8000;
    cors = {
      origins = ["*"];
      methods = ["GET" "POST"];
    };
    rate_limit = {
      requests = 100;
      period = "minute";
    };
  };
  
  # System information
  system = "x86_64-linux";
}