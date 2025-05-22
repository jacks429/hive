{
  inputs,
  cell,
}: {
  name = "news-categories";
  description = "Hierarchical taxonomy of news article categories";
  
  # Taxonomy format
  format = "hierarchical";
  
  # Category hierarchy
  categories = {
    politics = {
      description = "Political news";
      children = {
        domestic = {
          description = "Domestic politics";
          isLeaf = true;
        };
        international = {
          description = "International politics";
          isLeaf = true;
        };
        elections = {
          description = "Election news";
          isLeaf = true;
        };
      };
    };
    business = {
      description = "Business news";
      children = {
        markets = {
          description = "Financial markets";
          isLeaf = true;
        };
        economy = {
          description = "Economic news";
          isLeaf = true;
        };
        companies = {
          description = "Company news";
          isLeaf = true;
        };
      };
    };
    technology = {
      description = "Technology news";
      children = {
        ai = {
          description = "Artificial Intelligence";
          isLeaf = true;
        };
        software = {
          description = "Software development";
          isLeaf = true;
        };
        hardware = {
          description = "Hardware and devices";
          isLeaf = true;
        };
      };
    };
  };
  
  # Optional metadata
  metadata = {
    version = "1.0";
    author = "Example Team";
    lastUpdated = "2023-06-01";
  };
  
  # System information
  system = "x86_64-linux";
}