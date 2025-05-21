{
  inputs,
  cell,
}: {
  name = "word-tokenization";
  description = "Tokenization rules for splitting text into words";
  
  # Rule type
  type = "tokenization";
  
  # Rules - list of regex patterns for tokenization
  rules = [
    {
      pattern = "[a-zA-Z0-9]+";
      description = "Basic word tokenization (alphanumeric sequences)";
    }
    {
      pattern = "[.,!?;:]";
      description = "Punctuation tokens";
    }
  ];
  
  # Format configuration
  format = "json";
  
  # Processing options
  caseSensitive = true;
  
  # What this rule applies to
  appliesTo = "text";
  
  # Language information
  language = "en";
  
  # System information
  system = "x86_64-linux";
}