{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "lexicons";
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
        
        # Lexicon type
        type = config.type or "generic"; # stopwords, gazetteer, sentiment, etc.
        
        # Source configuration
        source = config.source or null; # Path to source file or inline content
        format = config.format or "text"; # text, json, csv, tsv
        
        # Processing options
        caseSensitive = config.caseSensitive or false;
        normalize = config.normalize or true; # Apply normalization (lowercase, etc.)
        stemming = config.stemming or false; # Apply stemming
        lemmatization = config.lemmatization or false; # Apply lemmatization
        
        # Language information
        language = config.language or "en"; # ISO language code
        
        # Output configuration
        outputFormat = config.outputFormat or "text"; # text, json, binary, trie
        
        # System information
        system = config.system or system;
      }))
      (l.filterAttrs (_: config: config.system == system))
    ])
    renamer;
in
  walk