{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "pipelines";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano transformers;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Extract rich metadata from pipeline definition
        description = config.description or "";
        inputs = config.inputs or [];        # e.g. [ "./data/raw.csv" ]
        outputs = config.outputs or [];      # e.g. [ "./data/out.json" ]
        services = config.services or [];    # e.g. [ "qdrant", "elasticsearch" ]
        resources = config.resources or {};  # e.g. { cpu="1"; memory="2Gi"; }
        
        # Process steps with dependency information
        steps = l.map (step: {
          name = step.name;
          command = step.command;
          depends = step.depends or [];      # for DAG edges
        }) config.steps;
        
        # Preserve system information
        system = config.system;
      }))
      (l.mapAttrs (_: transformers.pipelines))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk