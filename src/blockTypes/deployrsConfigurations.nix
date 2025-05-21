{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;

  deployrsConfigurations = {
    name = "deployrsConfigurations";
    type = "deployrsConfiguration";
    collect = import ../collectors/default.nix;
    transform = import ../transformers/deploy-rs-single.nix;
    output = "deploy.nodes";
  };
in
  deployrsConfigurations
