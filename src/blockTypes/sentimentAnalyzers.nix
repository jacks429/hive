{
  nixpkgs,
  root,
}: {
  name = "sentimentAnalyzers";
  modelType = "sentimentAnalyzers";
  description = "Sentiment analysis models";
  
  collector = import ../collectors/sentimentAnalyzers.nix {
    inherit nixpkgs root;
    inputs = root;
  };
  
  transformer = import ../transformers/sentimentAnalyzers.nix {
    inherit nixpkgs root;
  };
}
