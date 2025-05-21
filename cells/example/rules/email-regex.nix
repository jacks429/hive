{
  inputs,
  cell,
}: {
  name = "email-regex";
  description = "Regular expression rules for email validation and extraction";
  
  # Rule type
  type = "regex";
  
  # Rules - list of regex patterns
  rules = [
    {
      pattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";
      flags = "i";
      description = "Basic email address pattern";
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