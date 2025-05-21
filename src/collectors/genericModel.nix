{ inputs, cell, kind, cliPrefix ? "run" }:
let
  inherit (inputs) nixpkgs;
  l = nixpkgs.lib // builtins;
  
  # Load all model configurations for this kind
  configs = cell.${kind} or {};
  
  # Create registry entries for each model
  registry = l.mapAttrs (name: config: {
    inherit (config) modelUri framework params;
    meta = {
      name = config.name or name;
      description = config.description or "";
      kind = kind;
      tags = config.tags or [];
      license = config.license or "unknown";
      metrics = config.metrics or {};
    } // (config.meta or {});
    service = config.service or {
      enable = false;
      host = "0.0.0.0";
      port = 8000;
    };
    system = config.system or "x86_64-linux";
  }) configs;
  
in {
  # Return the registry
  ${kind}Registry = registry;
}