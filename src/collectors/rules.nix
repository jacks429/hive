{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "rules";
  l = nixpkgs.lib // builtins;
  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Basic metadata
        name = config.name or target;
        description = config.description or "";
        
        # Rule type
        type = config.type or "regex"; # regex, normalization, filtering, tokenization, etc.
        
        # Rule definition
        rules = config.rules or []; # List of rule definitions
        
        # Rule format
        format = config.format or "text"; # text, json, yaml
        
        # Processing options
        caseSensitive = config.caseSensitive or false;
        
        # Language information (if applicable)
        language = config.language or "en"; # ISO language code
        
        # Pipeline integration
        appliesTo = config.appliesTo or "text"; # text, tokens, entities, etc.
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk