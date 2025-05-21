{
  inputs,
  cell,
}: {
  name = "text-normalization";
  description = "Text normalization rules for standardizing text";
  
  # Rule type
  type = "normalization";
  
  # Rules - list of pattern/replacement pairs
  rules = [
    {
      pattern = "don't";
      replacement = "do not";
      description = "Expand contraction: don't";
    }
    {
      pattern = "can't";
      replacement = "cannot";
      description = "Expand contraction: can't";
    }
    {
      pattern = "won't";
      replacement = "will not";
      description = "Expand contraction: won't";
    }
    {
      pattern = "I'm";
      replacement = "I am";
      description = "Expand contraction: I'm";
    }
    {
      pattern = "it's";
      replacement = "it is";
      description = "Expand contraction: it's";
    }
    {
      pattern = "they're";
      replacement = "they are";
      description = "Expand contraction: they're";
    }
    {
      pattern = "we're";
      replacement = "we are";
      description = "Expand contraction: we're";
    }
    {
      pattern = "you're";
      replacement = "you are";
      description = "Expand contraction: you're";
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