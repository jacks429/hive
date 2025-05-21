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
    vectorIngestor = inputs.${fragment}.${target};
    
    # Create a command to run the vector ingestor
    runVectorIngestor = ''
      echo "Running vector ingestor: ${vectorIngestor.name}"
      ${vectorIngestor.runner}/bin/run-vectorIngestors-${target}
    '';
    
    # Create a command to show documentation
    showDocs = ''
      echo "Vector ingestor documentation for: ${vectorIngestor.name}"
      cat ${vectorIngestor.docs}/share/doc/vectorIngestors-${target}.md
    '';
    
  in {
    # Commands
    "${currentSystem}" = {
      # Run commands
      "run-vectorIngestors-${target}" = pkgs.writeShellScriptBin "run-vectorIngestors-${target}" runVectorIngestor;
      
      # Documentation
      "docs-vectorIngestors-${target}" = pkgs.writeShellScriptBin "docs-vectorIngestors-${target}" showDocs;
    };
  };
}