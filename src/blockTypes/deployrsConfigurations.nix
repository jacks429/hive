{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;

  deployrsConfigurations = {
    name = "deployrsConfigurations";
    type = "deployrsConfiguration";
    transform = import ../transformers/deployrsConfigurations.nix;
    output = "deploy.nodes";

    # Optional: Add actions for testing/deployment
    actions = {
      currentSystem,
      fragment,
      fragmentRelPath,
      target,
      inputs,
    }: let
      inherit (root) mkCommand;
    in [
      (mkCommand currentSystem {
        name = "check";
        description = "Check deploy-rs configuration";
        command = ''
          ${inputs.deploy-rs.packages.${currentSystem}.deploy-rs}/bin/deploy check
        '';
      })
      (mkCommand currentSystem {
        name = "dry-run";
        description = "Perform a dry-run deployment";
        command = ''
          ${inputs.deploy-rs.packages.${currentSystem}.deploy-rs}/bin/deploy .#${target} --dry-run
        '';
      })
      (mkCommand currentSystem {
        name = "deploy";
        description = "Deploy the configuration";
        command = ''
          ${inputs.deploy-rs.packages.${currentSystem}.deploy-rs}/bin/deploy .#${target}
        '';
      })
    ];
  };
in
  deployrsConfigurations
