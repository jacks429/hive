{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create a notebook file from template or empty
  notebookFile = 
    if config ? template then
      pkgs.writeTextFile {
        name = "${config.name}.ipynb";
        text = builtins.toJSON config.template;
      }
    else
      pkgs.writeTextFile {
        name = "${config.name}.ipynb";
        text = builtins.toJSON {
          cells = [];
          metadata = {
            kernelspec = {
              display_name = "Python 3";
              language = "python";
              name = "python3";
            };
          };
          nbformat = 4;
          nbformat_minor = 5;
        };
      };
  
  # Create a script to launch the notebook
  launchScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Launching Jupyter notebook: ${config.name}"
    
    # Create a directory for the notebook
    NOTEBOOK_DIR="$(mktemp -d -t notebook-${config.name}-XXXXXX)"
    
    # Copy the notebook template to the directory
    cp ${notebookFile} "$NOTEBOOK_DIR/${config.name}.ipynb"
    
    # Launch Jupyter notebook server
    cd "$NOTEBOOK_DIR"
    exec ${pkgs.python3.withPackages (ps: 
      l.map (dep: ps.${dep}) config.dependencies.python
    )}/bin/jupyter notebook "${config.name}.ipynb"
  '';
  
  # Create launch script derivation
  launchDrv = pkgs.writeScriptBin "launch-notebook-${config.name}" launchScript;
  
  # Create documentation
  documentation = ''
    # Jupyter Notebook: ${config.name}
    
    ${config.description}
    
    ## Kernel
    
    This notebook uses the **${config.kernelName}** kernel.
    
    ## Dependencies
    
    ### Python Packages
    
    ${l.concatMapStrings (dep: "- ${dep}\n") config.dependencies.python}
    
    ## Usage
    
    ```bash
    nix run .#launch-notebook-${config.name}
    ```
    
    This will create a temporary directory with the notebook and launch a Jupyter server.
  '';
  
  # Create documentation derivation
  docsDrv = pkgs.writeTextFile {
    name = "${config.name}-docs.md";
    text = documentation;
  };
  
in {
  launch = launchDrv;
  notebook = notebookFile;
  docs = docsDrv;
}