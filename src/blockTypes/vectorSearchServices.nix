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
    vectorSearchService = inputs.${fragment}.${target};
    
    # Create a command to run the vector search service
    serveVectorSearchService = ''
      echo "Starting vector search service: ${vectorSearchService.name}"
      ${vectorSearchService.service}/bin/serve-vectorSearchServices-${target}
    '';
    
    # Create a command to show documentation
    showDocs = ''
      echo "Vector search service documentation for: ${vectorSearchService.name}"
      cat ${vectorSearchService.docs}/share/doc/vectorSearchServices-${target}.md
    '';
    
  in {
    # Commands
    "${currentSystem}" = {
      # Run commands
      "serve-vectorSearchServices-${target}" = pkgs.writeShellScriptBin "serve-vectorSearchServices-${target}" runVectorSearchService;
      
      # Documentation
      "docs-vectorSearchServices-${target}" = pkgs.writeShellScriptBin "docs-vectorSearchServices-${target}" showDocs;
    };
  };
}
