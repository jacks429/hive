{
  inputs,
  cell,
}: {
  name = "noise-filtering";
  description = "Filtering rules to remove noise from text data";
  
  # Rule type
  type = "filtering";
  
  # Rules - list of conditions to filter out
  rules = [
    {
      condition = "^\\s*$";
      description = "Remove empty lines";
    }
    {
      condition = "^#.*$";
      description = "Remove comment lines starting with #";
    }
    {
      condition = "^\\s*//.*$";
      description = "Remove comment lines starting with //";
    }
    {
      condition = "^\\s*NOTE:.*$";
      description = "Remove note lines";
    }
    {
      condition = "^\\s*TODO:.*$";
      description = "Remove todo lines";
    }
    {
      condition = "^\\s*FIXME:.*$";
      description = "Remove fixme lines";
    }
  ];
  
  # Format configuration
  format = "json";
  
  # Processing options
  caseSensitive = false;
  
  # What this rule applies to
  appliesTo = "text";
  
  # Language information
  language = "en";
  
  # System information
  system = "x86_64-linux";
}