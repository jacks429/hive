{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract experiment trial configuration
  experiment = config;
  
  # Helper function to generate all combinations of parameters
  generateParameterGrid = paramGrid:
    let
      # Convert parameter grid to list of key-value pairs
      paramList = l.mapAttrsToList (name: values: {
        inherit name;
        inherit values;
      }) paramGrid;
      
      # Generate all combinations recursively
      combine = params: acc:
        if params == [] then
          [acc]
        else
          let
            param = l.head params;
            rest = l.tail params;
          in
            l.concatMap (value:
              combine rest (acc // { ${param.name} = value; })
            ) param.values;
    in
      combine paramList {};
  
  # Generate all parameter combinations based on strategy
  parameterCombinations = 
    if experiment.strategy == "grid" then
      # For grid search, generate all combinations
      generateParameterGrid experiment.parameterGrid
    else if experiment.strategy == "random" then
      # For random search, generate a subset of combinations
      let
        allCombinations = generateParameterGrid experiment.parameterGrid;
        maxTrials = if experiment.maxTrials != null then 
                      experiment.maxTrials 
                    else 
                      l.length allCombinations;
        # Use randomSeed for reproducibility
        # Note: This is a simplified version - in practice, you'd use a proper random sampling algorithm
        selectedIndices = l.genList (i: i * (l.length allCombinations / maxTrials)) maxTrials;
      in
        l.genAttrs selectedIndices (i: l.elemAt allCombinations i)
    else
      # Default to grid search
      generateParameterGrid experiment.parameterGrid;
  
  # Generate trial configurations
  trials = l.mapAttrs (index: params: {
    id = "${experiment.name}-trial-${toString index}";
    parameters = params;
    
    # Reference to the pipeline
    pipeline = experiment.pipeline;
    pipelineCell = experiment.pipelineCell;
    
    # Output path for this specific trial
    outputPath = "${experiment.outputPath}/trial-${toString index}";
    
    # Metrics to track
    metrics = experiment.metrics;
  }) parameterCombinations;
  
  # Generate execution script for a single trial
  generateTrialScript = trial: ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Starting trial: ${trial.id}"
    echo "Parameters: ${l.concatStringsSep " " (l.mapAttrsToList (name: value: "${name}=${toString value}") trial.parameters)}"
    
    # Create output directory
    mkdir -p ${trial.outputPath}
    
    # Run the pipeline with the trial parameters
    nix run .#run-${trial.pipelineCell}-${trial.pipeline} -- ${
      l.concatStringsSep " " (l.mapAttrsToList (name: value: "--${name} ${toString value}") trial.parameters)
    }
    
    # Collect metrics
    echo "Collecting metrics..."
    ${l.concatMapStrings (metric: ''
      if [ -f "${metric.path}" ]; then
        VALUE=$(${metric.extract})
        echo "${metric.name}: $VALUE"
        echo "${metric.name}=$VALUE" >> ${trial.outputPath}/metrics.txt
      else
        echo "Warning: Metric file ${metric.path} not found"
      fi
    '') trial.metrics}
    
    echo "Trial ${trial.id} completed"
  '';
  
  # Generate execution script for all trials
  executionScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Starting experiment: ${experiment.name}"
    echo "${experiment.description}"
    
    # Create output directory
    mkdir -p ${experiment.outputPath}
    
    # Run all trials
    ${l.concatMapStrings (trial: ''
      echo "Running trial: ${trial.id}"
      ${generateTrialScript trial}
      
      # Check for early stopping
      ${if experiment.earlyStoppingConfig != null then ''
        if [ -f "${experiment.outputPath}/stop_early" ]; then
          echo "Early stopping triggered"
          break
        fi
        
        # Check if we should stop early based on metrics
        if [ -f "${trial.outputPath}/metrics.txt" ]; then
          METRIC_VALUE=$(grep "${experiment.earlyStoppingConfig.metric}" ${trial.outputPath}/metrics.txt | cut -d= -f2)
          if ${if experiment.earlyStoppingConfig.direction == "minimize" then "[" else "! [" } "$METRIC_VALUE" ${if experiment.earlyStoppingConfig.direction == "minimize" then "<" else ">" } "${toString experiment.earlyStoppingConfig.threshold}" ]; then
            echo "Early stopping: ${experiment.earlyStoppingConfig.metric} = $METRIC_VALUE ${if experiment.earlyStoppingConfig.direction == "minimize" then "is less than" else "is greater than"} threshold ${toString experiment.earlyStoppingConfig.threshold}"
            touch "${experiment.outputPath}/stop_early"
            break
          fi
        fi
      '' else ""}
    '') (l.attrValues trials)}
    
    # Generate summary report
    echo "Generating summary report..."
    
    # Create summary table header
    echo "| Trial ID | ${l.concatStringsSep " | " (l.mapAttrsToList (name: _: name) (l.head (l.attrValues trials)).parameters)} | ${l.concatStringsSep " | " (map (m: m.name) experiment.metrics)} |" > ${experiment.outputPath}/summary.md
    echo "|${l.concatStringsSep "|" (l.genList (_: "---") (2 + l.length (l.attrNames (l.head (l.attrValues trials)).parameters) + l.length experiment.metrics))}|" >> ${experiment.outputPath}/summary.md
    
    # Add each trial's results to the summary
    ${l.concatMapStrings (trial: ''
      if [ -f "${trial.outputPath}/metrics.txt" ]; then
        echo -n "| ${trial.id} | ${l.concatStringsSep " | " (l.mapAttrsToList (name: value: toString value) trial.parameters)} |" >> ${experiment.outputPath}/summary.md
        ${l.concatMapStrings (metric: ''
          METRIC_VALUE=$(grep "${metric.name}" ${trial.outputPath}/metrics.txt | cut -d= -f2 || echo "N/A")
          echo -n " $METRIC_VALUE |" >> ${experiment.outputPath}/summary.md
        '') experiment.metrics}
        echo "" >> ${experiment.outputPath}/summary.md
      fi
    '') (l.attrValues trials)}
    
    # Find best trial based on primary metric
    if [ -n "${experiment.metrics}" ] && [ ${l.length experiment.metrics} -gt 0 ]; then
      PRIMARY_METRIC="${(l.head experiment.metrics).name}"
      echo "Finding best trial based on $PRIMARY_METRIC..."
      
      BEST_TRIAL=""
      BEST_VALUE=""
      
      ${l.concatMapStrings (trial: ''
        if [ -f "${trial.outputPath}/metrics.txt" ]; then
          METRIC_VALUE=$(grep "$PRIMARY_METRIC" ${trial.outputPath}/metrics.txt | cut -d= -f2 || echo "")
          if [ -n "$METRIC_VALUE" ]; then
            if [ -z "$BEST_VALUE" ]; then
              BEST_VALUE="$METRIC_VALUE"
              BEST_TRIAL="${trial.id}"
            elif ${if (l.head experiment.metrics).direction or "maximize" == "maximize" then "[" else "! [" } "$METRIC_VALUE" ${if (l.head experiment.metrics).direction or "maximize" == "maximize" then ">" else "<" } "$BEST_VALUE" ]; then
              BEST_VALUE="$METRIC_VALUE"
              BEST_TRIAL="${trial.id}"
            fi
          fi
        fi
      '') (l.attrValues trials)}
      
      if [ -n "$BEST_TRIAL" ]; then
        echo "Best trial: $BEST_TRIAL with $PRIMARY_METRIC = $BEST_VALUE"
        echo "Best trial: $BEST_TRIAL with $PRIMARY_METRIC = $BEST_VALUE" >> ${experiment.outputPath}/summary.md
        
        # Create a symlink to the best trial
        ln -sf "trial-${l.head (l.splitString "-" (l.head (l.tail (l.splitString "-" "$BEST_TRIAL"))))}" ${experiment.outputPath}/best_trial
      fi
    fi
    
    echo "Experiment ${experiment.name} completed"
    echo "Results available at ${experiment.outputPath}"
  '';
  
  # Generate documentation
  documentation = ''
    # Experiment: ${experiment.name}
    
    ${experiment.description}
    
    ## Pipeline
    
    This experiment runs the pipeline `${experiment.pipelineCell}-${experiment.pipeline}`.
    
    ## Parameter Grid
    
    The following parameters are varied in this experiment:
    
    ${l.concatMapStrings (param: ''
      - **${param.name}**: ${l.concatStringsSep ", " (map toString param.values)}
    '') (l.mapAttrsToList (name: values: { inherit name values; }) experiment.parameterGrid)}
    
    ## Trials
    
    This experiment will run ${toString (l.length (l.attrNames trials))} trials with the following parameter combinations:
    
    | Trial ID | ${l.concatStringsSep " | " (l.mapAttrsToList (name: _: name) experiment.parameterGrid)} |
    |${l.concatStringsSep "|" (l.genList (_: "---") (2 + l.length (l.attrNames experiment.parameterGrid)))}|
    ${l.concatMapStrings (trial: ''
      | ${trial.id} | ${l.concatStringsSep " | " (l.mapAttrsToList (name: value: toString value) trial.parameters)} |
    '') (l.attrValues trials)}
    
    ## Metrics
    
    The following metrics will be tracked:
    
    ${l.concatMapStrings (metric: ''
      - **${metric.name}**: ${metric.description or ""}
    '') experiment.metrics}
    
    ## Strategy
    
    This experiment uses the **${experiment.strategy}** search strategy.
    
    ${if experiment.earlyStoppingConfig != null then ''
      ## Early Stopping
      
      Early stopping will be triggered if the metric `${experiment.earlyStoppingConfig.metric}` ${if experiment.earlyStoppingConfig.direction == "minimize" then "falls below" else "exceeds"} the threshold value of `${toString experiment.earlyStoppingConfig.threshold}`.
    '' else ""}
    
    ## Running the Experiment
    
    To run this experiment, use:
    
    ```bash
    nix run .#run-experiment-${experiment.name}
    ```
    
    Results will be available in `${experiment.outputPath}`.
  '';
  
  # Generate visualization script
  visualizationScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Generating visualizations for experiment: ${experiment.name}"
    
    # Check if Python and matplotlib are available
    if ! command -v python3 &> /dev/null; then
      echo "Error: Python 3 is required for visualization"
      exit 1
    fi
    
    # Create visualization directory
    mkdir -p ${experiment.outputPath}/visualizations
    
    # Generate parameter importance plot
    cat > ${experiment.outputPath}/visualizations/generate_plots.py << 'EOF'
    import os
    import pandas as pd
    import matplotlib.pyplot as plt
    import numpy as np
    
    # Read the summary data
    summary_file = "${experiment.outputPath}/summary.md"
    
    # Parse the markdown table
    with open(summary_file, 'r') as f:
        lines = f.readlines()
    
    # Extract headers
    headers = [h.strip() for h in lines[0].strip('|').split('|')]
    
    # Extract data
    data = []
    for line in lines[2:]:
        if line.startswith('|') and 'Best trial' not in line:
            row = [cell.strip() for cell in line.strip('|').split('|')]
            if len(row) == len(headers):
                data.append(row)
    
    # Create DataFrame
    df = pd.DataFrame(data, columns=headers)
    
    # Convert numeric columns
    for col in df.columns[2:]:  # Skip Trial ID and parameter columns that might be categorical
        try:
            df[col] = pd.to_numeric(df[col])
        except:
            pass
    
    # Plot parameter vs. metric for each parameter and metric
    params = headers[1:${toString (1 + l.length (l.attrNames experiment.parameterGrid))}]
    metrics = headers[${toString (1 + l.length (l.attrNames experiment.parameterGrid))}:]
    
    for param in params:
        for metric in metrics:
            try:
                plt.figure(figsize=(10, 6))
                plt.scatter(df[param], df[metric])
                plt.xlabel(param)
                plt.ylabel(metric)
                plt.title(f"{param} vs {metric}")
                plt.grid(True)
                plt.savefig(f"${experiment.outputPath}/visualizations/{param}_vs_{metric}.png")
                plt.close()
            except Exception as e:
                print(f"Error plotting {param} vs {metric}: {e}")
    
    # Generate parallel coordinates plot for all parameters and the primary metric
    if len(metrics) > 0:
        primary_metric = metrics[0]
        try:
            from pandas.plotting import parallel_coordinates
            
            # Normalize the data for better visualization
            df_norm = df.copy()
            for col in params + [primary_metric]:
                if df_norm[col].dtype.kind in 'ifc':  # if column is numeric
                    df_norm[col] = (df_norm[col] - df_norm[col].min()) / (df_norm[col].max() - df_norm[col].min())
            
            # Add a class column based on metric quartiles
            df_norm['Performance'] = pd.qcut(df_norm[primary_metric], 4, labels=['Q1', 'Q2', 'Q3', 'Q4'])
            
            plt.figure(figsize=(12, 8))
            parallel_coordinates(df_norm, 'Performance', cols=params, colormap='viridis')
            plt.title(f"Parallel Coordinates Plot (colored by {primary_metric} quartiles)")
            plt.grid(True)
            plt.savefig(f"${experiment.outputPath}/visualizations/parallel_coordinates.png")
            plt.close()
        except Exception as e:
            print(f"Error generating parallel coordinates plot: {e}")
    
    # Generate heatmap for parameter interactions
    if len(params) >= 2 and len(metrics) > 0:
        primary_metric = metrics[0]
        try:
            # For each pair of parameters, create a heatmap of the metric
            for i, param1 in enumerate(params[:-1]):
                for param2 in params[i+1:]:
                    if df[param1].dtype.kind in 'ifc' and df[param2].dtype.kind in 'ifc':
                        plt.figure(figsize=(10, 8))
                        
                        # Create pivot table
                        heatmap_data = df.pivot_table(
                            values=primary_metric, 
                            index=param1, 
                            columns=param2, 
                            aggfunc='mean'
                        )
                        
                        plt.imshow(heatmap_data, cmap='viridis', interpolation='nearest', aspect='auto')
                        plt.colorbar(label=primary_metric)
                        plt.xlabel(param2)
                        plt.ylabel(param1)
                        plt.title(f"Interaction between {param1} and {param2} (color = {primary_metric})")
                        plt.savefig(f"${experiment.outputPath}/visualizations/heatmap_{param1}_{param2}.png")
                        plt.close()
        except Exception as e:
            print(f"Error generating heatmap: {e}")
    EOF
    
    # Run the Python script to generate visualizations
    cd ${experiment.outputPath}
    python3 visualizations/generate_plots.py
    
    echo "Visualizations generated in ${experiment.outputPath}/visualizations/"
  '';
  
  # Create derivations for the scripts
  executionScriptDrv = pkgs.writeScriptBin "run-experiment-${experiment.name}" executionScript;
  documentationDrv = pkgs.writeTextFile {
    name = "experiment-${experiment.name}-docs";
    text = documentation;
    destination = "/share/doc/experiment-${experiment.name}.md";
  };
  visualizationScriptDrv = pkgs.writeScriptBin "visualize-experiment-${experiment.name}" visualizationScript;
  
  # Create a derivation that bundles everything together
  experimentDrv = pkgs.symlinkJoin {
    name = "experiment-${experiment.name}";
    paths = [
      executionScriptDrv
      documentationDrv
      visualizationScriptDrv
    ];
  };
  
in {
  # Original experiment configuration
  inherit (experiment) name description system;
  inherit (experiment) pipeline pipelineCell parameterGrid metrics;
  inherit (experiment) outputPath strategy maxTrials randomSeed;
  
  # Generated trial configurations
  inherit trials;
  
  # Derivations
  runner = executionScriptDrv;
  docs = documentationDrv;
  visualizer = visualizationScriptDrv;
  package = experimentDrv;
  
  # Metadata
  metadata = {
    type = "experiment";
    trialCount = l.length (l.attrNames trials);
    parameterCount = l.length (l.attrNames experiment.parameterGrid);
    metricCount = l.length experiment.metrics;
  };
}
