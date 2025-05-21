{
  nixpkgs,
  root,
}: notebook: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${notebook.system};
  
  # Create a script to run the notebook
  runScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running notebook: ${notebook.name}"
    
    # Create temporary directory for notebook
    NOTEBOOK_DIR=$(mktemp -d)
    trap "rm -rf $NOTEBOOK_DIR" EXIT
    
    # Copy notebook file to temp directory
    cp ${notebook.path} $NOTEBOOK_DIR/${notebook.name}.ipynb
    
    # Copy data files if specified
    ${if notebook.dataFiles != null then ''
      mkdir -p $NOTEBOOK_DIR/data
      ${l.concatMapStrings (file: "cp ${file} $NOTEBOOK_DIR/data/\n") notebook.dataFiles}
    '' else ""}
    
    # Execute notebook
    cd $NOTEBOOK_DIR
    jupyter nbconvert --to notebook --execute ${notebook.name}.ipynb --output ${notebook.name}-output.ipynb
    
    # Copy output to specified location if provided
    ${if notebook.outputPath != null then ''
      mkdir -p $(dirname ${notebook.outputPath})
      cp ${notebook.name}-output.ipynb ${notebook.outputPath}
      echo "Notebook output saved to ${notebook.outputPath}"
    '' else ''
      cp ${notebook.name}-output.ipynb ./${notebook.name}-output.ipynb
      echo "Notebook output saved to ./${notebook.name}-output.ipynb"
    ''}
  '';
  
  # Create a script to serve the notebook
  serveScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting Jupyter server for notebook: ${notebook.name}"
    echo "Server will be available at http://${notebook.server.host or "localhost"}:${toString (notebook.server.port or 8888)}"
    
    # Create temporary directory for notebook
    NOTEBOOK_DIR=$(mktemp -d)
    trap "rm -rf $NOTEBOOK_DIR" EXIT
    
    # Copy notebook file to temp directory
    cp ${notebook.path} $NOTEBOOK_DIR/${notebook.name}.ipynb
    
    # Copy data files if specified
    ${if notebook.dataFiles != null then ''
      mkdir -p $NOTEBOOK_DIR/data
      ${l.concatMapStrings (file: "cp ${file} $NOTEBOOK_DIR/data/\n") notebook.dataFiles}
    '' else ""}
    
    # Start Jupyter server
    cd $NOTEBOOK_DIR
    jupyter notebook --ip=${notebook.server.host or "localhost"} --port=${toString (notebook.server.port or 8888)} --no-browser
  '';
  
  # Create run script derivation
  runDrv = pkgs.writeScriptBin "run-notebook-${notebook.name}" runScript;
  
  # Create serve script derivation
  serveDrv = pkgs.writeScriptBin "serve-notebook-${notebook.name}" serveScript;
  
in {
  run = runDrv;
  serve = serveDrv;
}