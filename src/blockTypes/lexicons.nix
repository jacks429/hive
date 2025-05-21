{
  nixpkgs,
  root,
}: {
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    lexicon = inputs.${fragment}.${target};
    
    # Create a command to compile the lexicon
    compileLexicon = ''
      echo "Compiling lexicon: ${lexicon.name}"
      ${lexicon.compiler}/bin/compile-lexicon-${lexicon.name}
    '';
    
    # Create a command to use the lexicon
    useLexicon = ''
      if [ $# -lt 1 ]; then
        echo "Usage: use INPUT_FILE [OUTPUT_FILE]"
        echo "Process INPUT_FILE using the ${lexicon.name} lexicon and write to OUTPUT_FILE"
        exit 1
      fi
      
      ${lexicon.processor}/bin/use-