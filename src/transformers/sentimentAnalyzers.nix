{ inputs, nixpkgs, root }:
import ./genericModel.nix {
  inherit inputs nixpkgs root;
  kind = "sentimentAnalyzers";
  cliPrefix = "run";
  servicePrefix = "serve";
}