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
    embeddingService = inputs.${fragment}.${target};
    
    # Create a command to run the embedding service
    runEmbeddingService = ''
      echo "Running embedding service: ${embeddingService.meta.name}"
      ${embeddingService.runner}/bin/run-embeddingServices-${target}
    '';
    
    # Create a command to serve the embedding service
    serveEmbeddingService = ''
      echo "Starting embedding service: ${embeddingService.meta.name}"
      ${embeddingService.service}/bin/serve-embeddingServices-${target}
    '';
    
    # Create a command to show documentation
    showDocs = ''
      echo "Embedding service documentation for: ${embeddingService.meta.name}"
      cat ${embeddingService.docs}/share/doc/embeddingServices-${target}.md
    '';
    
  in {
    # Commands
    "${currentSystem}" = {
      # Run commands
      "run-embeddingServices-${target}" = pkgs.writeShellScriptBin "run-embeddingServices-${target}" runEmbeddingService;
      
      # Service commands
      "serve-embeddingServices-${target}" = pkgs.writeShellScriptBin "serve-embeddingServices-${target}" serveEmbeddingService;
      
      # Documentation
      "docs-embeddingServices-${target}" = pkgs.writeShellScriptBin "docs-embeddingServices-${target}" showDocs;
    };
  };
}
