{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "datasets";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano transformers;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: transformers.datasets))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk
