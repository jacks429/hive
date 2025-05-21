{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Apply defaults to configuration
  notebook = transformers.withDefaults config {
    kernelName = "Python 3";
    dependencies = { python = []; };
  };
  
  # Create a notebook file from template or empty
  notebookFile = 
    if notebook ? template then
      pkgs.writeTextFile {
        name = "${notebook.name}.ipynb";
        text = transformers.toJSON notebook.template;
      }
    else
      pkgs.writeTextFile {
        name = "${notebook.name}.ipynb";
        text = transformers.toJSON {
          cells = [];
          metadata = {
            kernelspec = {
              display_name = notebook.kernelName;
              language = "python";
              name = "python3";
            };
          };
          nbformat = 4;
          nbformat_minor = 5;
        };
      };
  
  # Create a script to launch the notebook using the transformers library
  launchScript = transformers.withArgs {
    name = "launch-notebook-${notebook.name}";
    description = "Launch Jupyter notebook: ${notebook.name}";
  } ''
    echo "Launching Jupyter notebook: ${notebook.name}"
    
    # Create a directory for the notebook
    NOTEBOOK_DIR="$(mktemp -d -t notebook-${notebook.name}-XXXXXX)"
    
    # Copy the notebook template to the directory
    cp ${notebookFile} "$NOTEBOOK_DIR/${notebook.name}.ipynb"
    
    # Launch Jupyter notebook server
    cd "$NOTEBOOK_DIR"
    exec ${pkgs.python3.withPackages (ps: 
      l.map (dep: ps.${dep}) notebook.dependencies.python
    )}/bin/jupyter notebook "${notebook.name}.ipynb"
  '';
  
  # Generate documentation using the transformers library
  notebookDocs = transformers.generateDocs {
    name = "Jupyter Notebook: ${notebook.name}";
    description = notebook.description;
    usage = ''
      ```bash
      # Launch the notebook
      launch-notebook-${notebook.name}
      ```
      
      This will create a temporary directory with the notebook and launch a Jupyter server.
    '';
    examples = ''
      ```bash
      # Launch the notebook
      launch-notebook-${notebook.name}
      ```
    '';
    params = {
      kernelName = {
        description = "Jupyter kernel to use";
        type = "string";
        value = notebook.kernelName;
      };
      dependencies = {
        description = "Dependencies required by the notebook";
        type = "attrset";
        value = notebook.dependencies;
      };
    };
  };
  
  # Create derivations using the transformers library
  launchDrv = transformers.mkScript {
    name = "launch-notebook-${notebook.name}";
    description = "Launch Jupyter notebook: ${notebook.name}";
    script = launchScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${notebook.name}-notebook";
    content = notebookDocs;
  };
  
in {
  # Original notebook configuration
  inherit (notebook) name description kernelName dependencies;
  
  # Derivations
  launch = launchDrv;
  notebook = notebookFile;
  docs = docsDrv;
}
