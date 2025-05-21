{
  inputs,
  cell,
}: {
  name = "document-ingestor";
  description = "Ingest documents into vector store";
  
  collection = "document-embeddings";
  
  sources = [
    {
      type = "file";
      path = "/path/to/documents";
      patterns = ["*.pdf" "*.txt" "*.md"];
      recursive = true;
    }
    {
      type = "web";
      urls = [
        "https://example.com/docs"
      ];
      depth = 2;
      include_patterns = ["/docs/.*"];
      exclude_patterns = ["/docs/private/.*"];
    }
  ];
  
  processors = [
    {
      type = "text_splitter";
      chunk_size = 1000;
      chunk_overlap = 200;
    }
    {
      type = "metadata_extractor";
      fields = ["title" "author" "date"];
    }
  ];
  
  embedder = {
    type = "sentence-transformers";
    model = "all-MiniLM-L6-v2";
    batch_size = 32;
  };
  
  # System information
  system = "x86_64-linux";
}