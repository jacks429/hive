{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract quality gate definition
  gate = {
    inherit (config) name description type appliesTo timing required command timeout system;
  };
  
  # Validate gate type
  _ = assert l.elem gate.type ["lint" "test" "security" "performance" "custom"]; true;
  
  # Validate timing
  isValidTiming = 
    gate.timing == "before" || 
    gate.timing == "after" || 
    (l.hasPrefix "step:" gate.timing);
  
  __ = assert isValidTiming; true;
  
  # Return the gate with validation complete
  result = gate;
in
  result