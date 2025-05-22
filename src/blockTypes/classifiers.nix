{
  nixpkgs,
  root,
}: {
  name = "classifiers";
  type = "classifiers";
  description = "Machine learning classifiers";
  
  collector = import ../collectors/classifiers.nix {
    inherit nixpkgs root;
    inputs = root;
  };
  
  transformer = import ../transformers/classifiers.nix {
    inherit nixpkgs root;
  };
}