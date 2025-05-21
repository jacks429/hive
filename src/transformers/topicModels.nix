{ inputs, nixpkgs, root }:
import ./genericModel.nix {
  inherit inputs nixpkgs root;
  kind = "topicModels";
  cliPrefix = "run";
  servicePrefix = "serve";
}