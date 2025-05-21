{ inputs, cell }:
import ./genericModel.nix {
  inherit inputs cell;
  kind = "sentimentAnalyzers";
  cliPrefix = "run";
}