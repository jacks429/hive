{
  nixpkgs,
  root,
}: {
  name = "deepLearningModels";
  type = "deepLearningModels";
  description = "Deep learning models";
  
  collector = import ../collectors/deepLearningModels.nix {
    inherit nixpkgs root;
    inputs = root;
  };
  
  transformer = import ../transformers/deepLearningModels.nix {
    inherit nixpkgs root;
  };
}