{ inputs, cell }:
config: let
  l = builtins // inputs.nixpkgs.lib;
  
  # Create a derivation for the embedding service
  drv = {
    # Original model configuration
    inherit (config) modelUri framework params;
    inherit (config) meta service system;
    
    # Add CLI commands
    cli = {
      encode = ''
        echo "Encoding text with ${config.meta.description}"
        # Implementation would call the service API
      '';
      
      similarity = ''
        echo "Calculating similarity with ${config.meta.description}"
        # Implementation would call the service API
      '';
      
      search = ''
        echo "Searching with ${config.meta.description}"
        # Implementation would call the service API
      '';
    };
  };
  
in drv