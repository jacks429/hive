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
    experiment = inputs.${fragment}.${target};
    
    # Create a command to run the experiment
    runExperiment = ''
      echo "Running experiment: ${experiment.name}"
      ${experiment.runner}/bin/run-experiment-${experiment.name}
    '';
    
    # Create a command to visualize the experiment results
    visualizeExperiment = ''
      echo "Generating visualizations for experiment: ${experiment.name}"
      ${experiment.visualizer}/bin/visualize-experiment-${experiment.name}
    '';
    
    # Create a command to show experiment documentation
    showDocs = ''
      echo "Experiment documentation for: ${experiment.name}"
      cat ${experiment.docs}/share/doc/experiment-${experiment.name}.md
    '';
    
    # Create a command to list all trials
    listTrials = ''
      echo "Trials for experiment: ${experiment.name}"
      echo ""
      ${pkgs.lib.concatMapStrings (trial: ''
        echo "Trial: ${trial.id}"
        echo "Parameters: ${pkgs.lib.concatStringsSep " " (pkgs.lib.mapAttrsToList (name: value: "${name}=${toString value}") trial.parameters)}"
        echo ""
      '') (pkgs.lib.attrValues experiment.trials)}
    '';
    
    # Create a command to run a specific trial
    runTrial = ''
      if [ $# -lt 1 ]; then
        echo "Error: Missing trial index"
        echo "Usage: run-trial TRIAL_INDEX"
        exit 1
      fi
      
      TRIAL_INDEX="$1"
      
      if [ ! -v "''${experiment.trials.$TRIAL_INDEX}" ]; then
        echo "Error: Trial index $TRIAL_INDEX not found"
        echo "Available trials: ${pkgs.lib.concatStringsSep " " (pkgs.lib.attrNames experiment.trials)}"
        exit 1
      fi
      
      echo "Running trial: ${experiment.name}-trial-$TRIAL_INDEX"
      
      # Create output directory
      mkdir -p ${experiment.outputPath}/trial-$TRIAL_INDEX
      
      # Run the pipeline with the trial parameters
      PARAMS="${pkgs.lib.concatStringsSep " " (pkgs.lib.mapAttrsToList (name: value: "--${name} ${toString value}") (pkgs.lib.getAttr "$TRIAL_INDEX" experiment.trials).parameters)}"
      nix run .#run-${experiment.pipelineCell}-${experiment.pipeline} -- $PARAMS
      
      echo "Trial completed"
    '';
    
    # Helper function to create a command
    mkCommand = system: {
      name,
      description,
      command,
    }: {
      inherit name description;
      package = pkgs.writeShellScriptBin name command;
      type = "app";
    };
    
  in [
    (mkCommand currentSystem {
      name = "run";
      description = "Run the experiment";
      command = runExperiment;
    })
    (mkCommand currentSystem {
      name = "visualize";
      description = "Generate visualizations for experiment results";
      command = visualizeExperiment;
    })
    (mkCommand currentSystem {
      name = "docs";
      description = "Show experiment documentation";
      command = showDocs;
    })
    (mkCommand currentSystem {
      name = "list-trials";
      description = "List all trials in the experiment";
      command = listTrials;
    })
    (mkCommand currentSystem {
      name = "run-trial";
      description = "Run a specific trial";
      command = runTrial;
    })
  ];
}