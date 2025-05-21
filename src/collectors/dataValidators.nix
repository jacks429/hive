{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "dataValidators";

  l = nixpkgs.lib // builtins;

  inherit (root) walkPaisano;

  walk = self:
    walkPaisano self cellBlock (system: cell: [
      (l.mapAttrs (target: config: {
        _file = "Cell: ${cell} - Block: ${cellBlock} - Target: ${target}";
        imports = [config];
      }))
      (l.mapAttrs (_: config: {
        # Extract validator definition
        name = config.name or target;
        description = config.description or "";
        
        # Validator type
        type = config.type or "great-expectations";  # great-expectations, deequ, custom
        
        # Data source
        dataSource = config.dataSource or {
          type = "csv";
          path = "";
        };
        
        # Validation rules
        rules = config.rules or [];
        
        # Expectations (for Great Expectations)
        expectations = config.expectations or [];
        
        # Actions on validation failure
        onFailure = config.onFailure or {
          action = "report";  # report, fail, alert
          alertChannels = [];
        };
        
        # Custom code (optional)
        customCode = config.customCode or null;
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk