{ inputs, cell }:
import ./genericModel.nix {
  inherit inputs cell;
  kind = "topicModels";
  cliPrefix = "run";
}