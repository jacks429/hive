{
  inputs,
  cell,
}: {
  name = "document-embeddings";
  description = "Collection for document embeddings";
  
  store = "embeddings-store";
  
  schema = {
    dimensions = 768;
    distance = "cosine";
    
    payload_schema = {
      title = {
        type = "keyword";
        indexed = true;
      };
      content = {
        type = "text";
        indexed = true;
      };
      url = {
        type = "keyword";
        indexed = true;
      };
      created_at = {
        type = "datetime";
        indexed = true;
      };
      tags = {
        type = "keyword";
        indexed = true;
      };
    };
  };
  
  indexes = [
    {
      name = "title_index";
      field = "title";
      type = "text";
    }
    {
      name = "tags_index";
      field = "tags";
      type = "list";
    }
  ];
  
  # System information
  system = "x86_64-linux";
}