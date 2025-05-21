{
  inputs,
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create scheduler script
  schedulerScript = ''
    #!/usr/bin/env python
    
    import json
    import os
    import sys
    import argparse
    
    # Optimizer-specific imports
    ${if config.type == "grid" then ''
      from sklearn.model_selection import GridSearchCV
      import numpy as np
    '' else if config.type == "random" then ''
      from sklearn.model_selection import RandomizedSearchCV
      import numpy as np
    '' else if config.type == "bayesian" then ''
      import optuna
    '' else ''
      # Custom imports
      ${config.customCode.imports or "# No custom imports provided"}
    ''}
    
    # Parse arguments
    parser = argparse.ArgumentParser(description='Hyperparameter optimization for ${config.name}')
    parser.add_argument('--model-script', required=True, help='Path to model training script')
    parser.add_argument('--data-path', required=True, help='Path to dataset')
    parser.add_argument('--output-path', required=True, help='Path to save results')
    parser.add_argument('--config', default=None, help='Path to additional configuration')
    args = parser.parse_args()
    
    # Load additional configuration if provided
    additional_config = {}
    if args.config and os.path.exists(args.config):
        with open(args.config, 'r') as f:
            additional_config = json.load(f)
    
    # Define search space
    search_space = ${l.toJSON config.searchSpace}
    
    # Update search space with additional configuration
    search_space.update(additional_config.get('search_space', {}))
    
    # Define objective function
    ${if config.type == "bayesian" then ''
      def objective(trial):
          # Create hyperparameters for this trial
          params = {}
          for param_name, param_config in search_space.items():
              if param_config['type'] == 'categorical':
                  params[param_name] = trial.suggest_categorical(param_name, param_config['values'])
              elif param_config['type'] == 'int':
                  params[param_name] = trial.suggest_int(param_name, param_config['min'], param_config['max'], param_config.get('step', 1))
              elif param_config['type'] == 'float':
                  params[param_name] = trial.suggest_float(param_name, param_config['min'], param_config['max'], log=param_config.get('log', False))
          
          # Create command to run model script with these parameters
          param_str = json.dumps(params)
          cmd = f"{args.model_script} --data-path {args.data_path} --params '{param_str}' --output-path {args.output_path}/trial_{trial.number}"
          
          # Run command and capture output
          import subprocess
          result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
          
          # Parse results
          try:
              results = json.loads(result.stdout)
              return results.get('${config.objective.metric}', 0)
          except:
              print(f"Error parsing results: {result.stdout}")
              return 0 if '${config.objective.direction}' == 'maximize' else float('inf')
    '' else if config.type == "grid" || config.type == "random" then ''
      # Define a function to evaluate a set of hyperparameters
      def evaluate_params(params):
          # Create command to run model script with these parameters
          param_str = json.dumps(params)
          cmd = f"{args.model_script} --data-path {args.data_path} --params '{param_str}' --output-path {args.output_path}/trial"
          
          # Run command and capture output
          import subprocess
          result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
          
          # Parse results
          try:
              results = json.loads(result.stdout)
              return results.get('${config.objective.metric}', 0)
          except:
              print(f"Error parsing results: {result.stdout}")
              return 0 if '${config.objective.direction}' == 'maximize' else float('inf')
    '' else ''
      ${config.customCode.objective or "# No custom objective function provided"}
    ''}
    
    # Run optimization
    ${if config.type == "bayesian" then ''
      # Create Optuna study
      study = optuna.create_study(direction='${config.objective.direction}')
      
      # Run optimization
      study.optimize(objective, n_trials=${toString config.config.maxTrials}, n_jobs=${toString config.config.maxParallelTrials})
      
      # Get best parameters
      best_params = study.best_params
      best_value = study.best_value
      
      # Save results
      results = {
          'best_params': best_params,
          'best_value': best_value,
          'all_trials': [
              {
                  'number': trial.number,
                  'params': trial.params,
                  'value': trial.value,
                  'state': str(trial.state)
              }
              for trial in study.trials
          ]
      }
    '' else if config.type == "grid" then ''
      # Create parameter grid
      param_grid = {}
      for param_name, param_config in search_space.items():
          if param_config['type'] == 'categorical':
              param_grid[param_name] = param_config['values']
          elif param_config['type'] == 'int':
              param_grid[param_name] = list(range(param_config['min'], param_config['max'] + 1, param_config.get('step', 1)))
          elif param_config['type'] == 'float':
              if param_config.get('log', False):
                  param_grid[param_name] = np.logspace(np.log10(param_config['min']), np.log10(param_config['max']), num=10)
              else:
                  param_grid[param_name] = np.linspace(param_config['min'], param_config['max'], num=10)
      
      # Run grid search
      best_params = None
      best_value = float('-inf') if '${config.objective.direction}' == 'maximize' else float('inf')
      all_results = []
      
      # Generate all parameter combinations
      from itertools import product
      keys = param_grid.keys()
      for values in product(*param_grid.values()):
          params = dict(zip(keys, values))
          
          # Evaluate this parameter set
          value = evaluate_params(params)
          
          # Update best parameters if needed
          if ('${config.objective.direction}' == 'maximize' and value > best_value) or \
             ('${config.objective.direction}' == 'minimize' and value < best_value):
              best_params = params
              best_value = value
          
          # Save result
          all_results.append({
              'params': params,
              'value': value
          })
      
      # Save results
      results = {
          'best_params': best_params,
          'best_value': best_value,
          'all_trials': all_results
      }
    '' else if config.type == "random" then ''
      # Create parameter distributions
      param_distributions = {}
      for param_name, param_config in search_space.items():
          if param_config['type'] == 'categorical':
              param_distributions[param_name] = param_config['values']
          elif param_config['type'] == 'int':
              param_distributions[param_name] = list(range(param_config['min'], param_config['max'] + 1, param_config.get('step', 1)))
          elif param_config['type'] == 'float':
              if param_config.get('log', False):
                  param_distributions[param_name] = np.logspace(np.log10(param_config['min']), np.log10(param_config['max']), num=100)
              else:
                  param_distributions[param_name] = np.linspace(param_config['min'], param_config['max'], num=100)
      
      # Run random search
      best_params = None
      best_value = float('-inf') if '${config.objective.direction}' == 'maximize' else float('inf')
      all_results = []
      
      # Generate random parameter combinations
      import random
      for i in range(${toString config.config.maxTrials}):
          params = {}
          for param_name, distribution in param_distributions.items():
              params[param_name] = random.choice(distribution)
          
          # Evaluate this parameter set
          value = evaluate_params(params)
          
          # Update best parameters if needed
          if ('${config.objective.direction}' == 'maximize' and value > best_value) or \
             ('${config.objective.direction}' == 'minimize' and value < best_value):
              best_params = params
              best_value = value
          
          # Save result
          all_results.append({
              'params': params,
              'value': value
          })
      
      # Save results
      results = {
          'best_params': best_params,
          'best_value': best_value,
          'all_trials': all_results
      }
    '' else ''
      ${config.customCode.optimization or "# No custom optimization code provided"}
    ''}
    
    # Save results to output file
    os.makedirs(args.output_path, exist_ok=True)
    with open(f"{args.output_path}/results.json", 'w') as f:
        json.dump(results, f, indent=2)
    
    # Print best parameters
    print(f"Best parameters: {json.dumps(results['best_params'], indent=2)}")
    print(f"Best value: {results['best_value']}")
    
    # Create a configuration file with the best parameters
    with open(f"{args.output_path}/best_params.json", 'w') as f:
        json.dump(results['best_params'], f, indent=2)
    
    print(f"Results saved to {args.output_path}/results.json")
    print(f"Best parameters saved to {args.output_path}/best_params.json")
  '';
  
  # Create wrapper script
  wrapperScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Running hyperparameter optimization: ${config.name} (${config.type})"
    
    # Parse arguments
    MODEL_SCRIPT=""
    DATA_PATH=""
    OUTPUT_PATH=""
    CONFIG_PATH=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        --model-script)
          MODEL_SCRIPT="$2"
          shift 2
          ;;
        --data-path)
          DATA_PATH="$2"
          shift 2
          ;;
        --output-path)
          OUTPUT_PATH="$2"
          shift 2
          ;;
        --config)
          CONFIG_PATH="$2"
          shift 2
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done
    
    # Check required arguments
    if [ -z "$MODEL_SCRIPT" ] || [ -z "$DATA_PATH" ]; then
      echo "Usage: schedule-hyperparams-${config.name} --model-script <path> --data-path <path> [--output-path <path>] [--config <path>]"
      exit 1
    fi
    
    # Set default output path if not provided
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./hyperopt-${config.name}-results"
    fi
    
    # Run scheduler script
    ${pkgs.python3.withPackages (ps: with ps; [
      numpy
      scikit-learn
      (if config.type == "bayesian" then optuna else null)
    ])}/bin/python ${pkgs.writeText "schedule-hyperparams-${config.name}.py" schedulerScript} \
      --model-script "$MODEL_SCRIPT" \
      --data-path "$DATA_PATH" \
      --output-path "$OUTPUT_PATH" \
      ${if config.type == "custom" then "--config \"$CONFIG_PATH\"" else ""}
  '';
  
  # Create wrapper script derivation
  wrapperDrv = pkgs.writeScriptBin "schedule-hyperparams-${config.name}" wrapperScript;
  
  # Create documentation
  documentation = ''
    # Hyperparameter Scheduler: ${config.name}
    
    ${config.description}
    
    ## Type
    
    This scheduler uses the **${config.type}** optimization strategy.
    
    ## Parameters
    
    The following parameters will be optimized:
    
    ```json
    ${builtins.toJSON config.parameters}
    ```
    
    ## Search Space
    
    ```json
    ${builtins.toJSON config.searchSpace}
    ```
    
    ## Objective
    
    Optimize the **${config.objective.metric}** metric (${config.objective.direction}).
    
    ## Configuration
    
    - Maximum trials: ${toString config.config.maxTrials}
    - Maximum parallel trials: ${toString config.config.maxParallelTrials}
    - Early stopping rounds: ${toString config.config.earlyStoppingRounds}
    
    ## Usage
    
    ```bash
    nix run .#schedule-hyperparams-${config.name} -- \
      --model-script <path-to-model-script> \
      --data-path <path-to-data> \
      --output-path <path-to-save-results> \
      --config <optional-config-file>
    ```
    
    The model script should accept the following arguments:
    
    - `--data-path`: Path to the dataset
    - `--params`: JSON string with hyperparameters
    - `--output-path`: Path to save model and results
    
    The model script should output a JSON object with the metric value.
  '';
  
  # Create documentation derivation
  docsDrv = pkgs.writeTextFile {
    name = "${config.name}-docs.md";
    text = documentation;
  };
  
in {
  schedule = wrapperDrv;
  docs = docsDrv;
}