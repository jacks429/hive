{
  nixpkgs,
  root,
}: {
  name = "topicModels";
  type = "topicModels";
  description = "Topic modeling for text data";
  
  collector = import ../collectors/topicModels.nix {
    inherit nixpkgs root;
    inputs = root;
  };
  
  transformer = import ../transformers/topicModels.nix {
    inherit nixpkgs root;
  };
}