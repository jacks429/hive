{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "hooks";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Extract hook definition
        type = config.type or "preStep";  # preStep, postStep, onFailure
        description = config.description or "";
        
        # Target information - what this hook applies to
        appliesTo = config.appliesTo or "all";  # "all", specific pipeline name, or list of pipeline names
        steps = config.steps or [];  # empty means all steps, otherwise specific step names
        
        # The command to execute
        command = config.command or "";
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk