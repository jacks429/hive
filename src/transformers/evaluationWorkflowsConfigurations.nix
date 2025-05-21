{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract all evaluation workflows
  evaluationWorkflows = config.registry or {};
  
  # Generate a combined documentation file
  documentationDrv = pkgs.writeTextFile {
    name = "evaluation-workflows-documentation";
    text = config.documentation or "";
    destination = "/share/evaluation-workflows/documentation.md";
  };
  
  # Generate a combined diagram
  diagramDrv = pkgs.writeTextFile {
    name = "evaluation-workflows-diagram";
    text = config.combinedDiagram or "";
    destination = "/share/evaluation-workflows/combined-diagram.mmd";
  };
  
  # Create a script to generate all diagrams as SVG
  generateDiagramsScript = pkgs.writeShellScriptBin "generate-evaluation-diagrams" ''
    mkdir -p $PRJ_ROOT/evaluation-workflows
    
    # Generate combined diagram
    echo "Generating combined evaluation workflows diagram..."
    cp ${diagramDrv}/share/evaluation-workflows/combined-diagram.mmd $PRJ_ROOT/evaluation-workflows/
    
    # Convert to SVG if mermaid-cli is available
    if command -v mmdc &> /dev/null; then
      mmdc -i $PRJ_ROOT/evaluation-workflows/combined-diagram.mmd -o $PRJ_ROOT/evaluation-workflows/combined-diagram.svg
      echo "Combined diagram generated at evaluation-workflows/combined-diagram.svg"
    else
      echo "mermaid-cli not found. Install with 'npm install -g @mermaid-js/mermaid-cli' to generate SVG diagrams."
    fi
    
    # Copy documentation
    cp ${documentationDrv}/share/evaluation-workflows/documentation.md $PRJ_ROOT/evaluation-workflows/
    echo "Documentation generated at evaluation-workflows/documentation.md"
  '';
  
  # Create a script to list all available evaluation workflows
  listWorkflowsScript = pkgs.writeShellScriptBin "list-evaluation-workflows" ''
    echo "Available Evaluation Workflows:"
    echo ""
    ${l.concatMapStrings (name: ''
      echo "* ${name}"
      echo "  - Description: ${evaluationWorkflows.${name}.description}"
      echo "  - Data Loader: ${evaluationWorkflows.${name}.dataLoader}"
      echo "  - Model: ${evaluationWorkflows.${name}.model}"
      echo "  - Metrics: ${l.concatStringsSep ", " evaluationWorkflows.${name}.metrics}"
      echo ""
    '') (l.attrNames evaluationWorkflows)}
  '';
  
  # Create a package with all artifacts
  evaluationWorkflowsPackage = pkgs.symlinkJoin {
    name = "evaluation-workflows-package";
    paths = [
      documentationDrv
      diagramDrv
      generateDiagramsScript
      listWorkflowsScript
    ];
  };
  
in {
  # Original configuration
  inherit (config) registry documentation combinedDiagram;
  
  # Derivations
  docs = documentationDrv;
  diagram = diagramDrv;
  generateDiagrams = generateDiagramsScript;
  listWorkflows = listWorkflowsScript;
  package = evaluationWorkflowsPackage;
}