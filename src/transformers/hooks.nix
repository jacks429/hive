{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract hook definition
  hook = {
    inherit (config) type description appliesTo steps command system;
  };
  
  # Validate hook type
  _ = assert l.elem hook.type ["preStep" "postStep" "onFailure"]; true;
  
  # Return the hook with validation complete
  result = hook;
in
  result