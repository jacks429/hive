{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "deployrsConfigurations";

  l = nixpkgs.lib // builtins;

  inherit (root) requireInput walkPaisano checks transformers;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: checks.bee))
      (l.mapAttrs (_: transformers.deployrsConfigurations))
      (l.filterAttrs (_: config: config.bee.system == system))
    ])
    renamer;
in
  requireInput
  "deploy-rs"
  "github:serokell/deploy-rs"
  "`hive.collect \"deployrsConfigurations\"`"
  (self: {
    deploy.nodes = walk self;
    checks = l.genAttrs l.systems.flakeExposed (
      system:
        if inputs.deploy-rs.lib ? deployChecks
        then {deployChecks = inputs.deploy-rs.lib.deployChecks {nodes = walk self;};}
        else {}
    );
  })
