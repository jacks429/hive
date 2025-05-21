{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract pipeline definition
  pipeline = config;
  
  # Generate Mermaid diagram for documentation
  mermaidDiagram = let
    stepDiagrams = l.concatMapStrings (step: 
      if step.depends == [] then
        "    start-->\"${pipeline.name}.${step.name}\"\n"
      else
        l.concatMapStrings (dep:
          "    \"${pipeline.name}.${dep}\"-->\"${pipeline.name}.${step.name}\"\n"
        ) step.depends
    ) pipeline.steps;
  in ''
    flowchart TD
    ${stepDiagrams}
  '';
  
  # Get datasets registry
  datasetsRegistry = root.collectors.datasetsRegistry renamer;

  # Resolve dataset references in inputs
  resolvedInputs = datasetsRegistry.resolveDatasetReferences pipeline.inputs;

  # Get parameters registry
  parametersRegistry = root.collectors.parametersRegistry renamer;

  # Get parameters for this pipeline
  pipelineParameters = parametersRegistry.getParametersForGroup pipeline.name;

  # Function to resolve parameters with overrides
  resolveParameters = overrides:
    parametersRegistry.resolveParametersForGroup pipeline.name overrides;

  # Function to substitute parameters in a command string
  substituteParameters = params: cmd:
    l.foldl' (result: name:
      let value = params.${name}; in
      l.replaceStrings ["${name}"] ["${toString value}"] result
    ) cmd (l.attrNames params);

  # Collect all hooks that apply to this pipeline
  allHooks = let
    hooks = root.collectors.hooks (cell: target: "${cell}-${target}");
    
    # Filter hooks that apply to this pipeline
    relevantHooks = l.filterAttrs (name: hook:
      hook.appliesTo == "all" || 
      hook.appliesTo == pipeline.name ||
      (l.isList hook.appliesTo && l.elem pipeline.name hook.appliesTo)
    ) hooks;
  in relevantHooks;
  
  # Get hooks by type and step
  getHooksForStep = type: stepName: l.filter (hook:
    hook.type == type && 
    (hook.steps == [] || l.elem stepName hook.steps)
  ) (l.attrValues allHooks);
  
  # Generate hook command strings
  hookCommands = {
    preStep = stepName: let
      hooks = getHooksForStep "preStep" stepName;
    in l.concatMapStrings (hook: ''
      echo "🔄 Running preStep hook: ${hook.description}"
      ${hook.command}
      
      # Check hook exit status
      if [ $? -ne 0 ]; then
        echo "❌ preStep hook failed for step ${stepName}"
        exit 1
      fi
      
    '') hooks;
    
    postStep = stepName: let
      hooks = getHooksForStep "postStep" stepName;
    in l.concatMapStrings (hook: ''
      echo "🔄 Running postStep hook: ${hook.description}"
      ${hook.command}
      
      # Check hook exit status
      if [ $? -ne 0 ]; then
        echo "⚠️ postStep hook failed for step ${stepName} but continuing"
      fi
      
    '') hooks;
    
    onFailure = stepName: let
      hooks = getHooksForStep "onFailure" stepName;
    in l.concatMapStrings (hook: ''
      echo "🔄 Running onFailure hook: ${hook.description}"
      ${hook.command}
    '') hooks;
  };
  
  # Collect all quality gates that apply to this pipeline
  allGates = let
    gates = root.collectors.qualityGates (cell: target: "${cell}-${target}");
    
    # Filter gates that apply to this pipeline
    relevantGates = l.filterAttrs (name: gate:
      gate.appliesTo == "all" || 
      gate.appliesTo == pipeline.name ||
      (l.isList gate.appliesTo && l.elem pipeline.name gate.appliesTo)
    ) gates;
  in relevantGates;
  
  # Get gates by timing
  getGatesByTiming = timing: l.filter (gate:
    gate.timing == timing
  ) (l.attrValues allGates);
  
  # Get gates for a specific step
  getGatesForStep = stepName: l.filter (gate:
    gate.timing == "step:${stepName}"
  ) (l.attrValues allGates);
  
  # Generate gate command strings
  gateCommands = {
    before = let
      gates = getGatesByTiming "before";
    in l.concatMapStrings (gate: ''
      echo "🔍 Running quality gate (${gate.type}): ${gate.description}"
      ${if gate.timeout > 0 then "timeout ${toString gate.timeout}" else ""} ${gate.command}
      
      # Check gate exit status
      if [ $? -ne 0 ]; then
        echo "❌ Quality gate failed: ${gate.description}"
        ${if gate.required then "exit 1" else "echo \"⚠️ Non-required gate, continuing despite failure\""}
      fi
      
    '') gates;
    
    after = let
      gates = getGatesByTiming "after";
    in l.concatMapStrings (gate: ''
      echo "🔍 Running quality gate (${gate.type}): ${gate.description}"
      ${if gate.timeout > 0 then "timeout ${toString gate.timeout}" else ""} ${gate.command}
      
      # Check gate exit status
      if [ $? -ne 0 ]; then
        echo "❌ Quality gate failed: ${gate.description}"
        ${if gate.required then "exit 1" else "echo \"⚠️ Non-required gate, continuing despite failure\""}
      fi
      
    '') gates;
    
    step = stepName: let
      gates = getGatesForStep stepName;
    in l.concatMapStrings (gate: ''
      echo "🔍 Running quality gate (${gate.type}): ${gate.description}"
      ${if gate.timeout > 0 then "timeout ${toString gate.timeout}" else ""} ${gate.command}
      
      # Check gate exit status
      if [ $? -ne 0 ]; then
        echo "❌ Quality gate failed: ${gate.description}"
        ${if gate.required then "exit 1" else "echo \"⚠️ Non-required gate, continuing despite failure\""}
      fi
      
    '') gates;
  };
  
  # Create wrapper script for running the pipeline with quality gates
  runnerScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "🟢 Starting pipeline: ${pipeline.name}"
    
    # Run before-pipeline quality gates
    ${gateCommands.before}
    
    # Resolved inputs
    ${l.concatMapStrings (input: ''
      echo "📂 Input: ${input}"
    '') resolvedInputs}
    
    # Start required services
    ${l.optionalString (pipeline.services != []) ''
      echo "🟢 Starting services: ${l.concatStringsSep ", " pipeline.services}"
      ${l.concatMapStrings (svc: ''
        echo "  - Starting ${svc}..."
        nix run .#${svc} &
        SERVICE_PID_${svc}=$!
      '') pipeline.services}
    ''}
    
    # Execute steps in dependency order with quality gates
    ${let
      # Build dependency graph
      allSteps = l.map (step: step.name) pipeline.steps;
      stepsByName = l.listToAttrs (l.map (step: l.nameValuePair step.name step) pipeline.steps);
      
      # Topological sort
      visited = l.foldl' (acc: step: acc // { ${step} = false; }) {} allSteps;
      sorted = [];
      
      visit = node: visited: sorted:
        if visited.${node} then
          { inherit visited sorted; }
        else
          let
            newVisited = visited // { ${node} = true; };
            deps = stepsByName.${node}.depends or [];
            result = l.foldl'
              (acc: dep: visit dep acc.visited acc.sorted)
              { visited = newVisited; sorted = sorted; }
              deps;
          in {
            visited = result.visited;
            sorted = result.sorted ++ [node];
          };
      
      result = l.foldl'
        (acc: node: 
          if acc.visited.${node} then acc
          else visit node acc.visited acc.sorted
        )
        { inherit visited; sorted = []; }
        allSteps;
      
      # Generate execution script with quality gates
      executionScript = l.concatMapStrings (stepName:
        let step = stepsByName.${stepName}; in
        ''
          echo "▶️ Executing step: ${stepName}"
          
          # Run the actual step command
          ${step.command}
          
          # Check exit status
          if [ $? -ne 0 ]; then
            echo "❌ Step ${stepName} failed"
            exit 1
          fi
          
          # Run step-specific quality gates
          ${gateCommands.step stepName}
          
        ''
      ) result.sorted;
    in executionScript}
    
    # Run after-pipeline quality gates
    ${gateCommands.after}
    
    echo "✅ Pipeline ${pipeline.name} completed successfully"
  '';
  
  # Create wrapper derivation
  runnerDrv = pkgs.writeScriptBin "run-${pipeline.name}" runnerScript;

  # Create a runner script that accepts parameter overrides
  parameterizedRunnerScript = ''
    #!/usr/bin/env bash
    set -e
    
    # Parse command line arguments for parameter overrides
    PARAMS=()
    for arg in "$@"; do
      if [[ "$arg" =~ ^--([^=]+)=(.*)$ ]]; then
        PARAM_NAME="''${BASH_REMATCH[1]}"
        PARAM_VALUE="''${BASH_REMATCH[2]}"
        PARAMS+=("--param" "$PARAM_NAME" "$PARAM_VALUE")
      elif [[ "$arg" =~ ^--([^=]+)$ ]]; then
        PARAM_NAME="''${BASH_REMATCH[1]}"
        PARAM_VALUE="true"
        PARAMS+=("--param" "$PARAM_NAME" "$PARAM_VALUE")
      else
        PARAMS+=("$arg")
      fi
    done
    
    # Run the pipeline with parameter overrides
    ${runnerScript} "''${PARAMS[@]}"
  '';

  # Create a parameterized runner derivation
  parameterizedRunnerDrv = pkgs.writeScriptBin "run-${pipeline.name}-with-params" parameterizedRunnerScript;

  # Add parameter support to the pipeline configuration
  pipelineWithParameters = {
    # Original pipeline data
    inherit (pipeline) name system steps services inputs outputs resources description;
    
    # Enhanced outputs
    mermaidDiagram = mermaidDiagram;
    runner = runnerDrv;
    parameterizedRunner = parameterizedRunnerDrv;
    
    # Add parameters
    parameters = pipelineParameters;
    resolveParameters = resolveParameters;
    
    # Add metadata for pipeline execution
    metadata = pipeline.metadata or {};
  };

  # Get environments registry
  environmentsRegistry = root.collectors.environmentsRegistry renamer;

  # Function to create an environment-aware runner
  createEnvironmentAwareRunner = envName: let
    # Get environment variables
    envVars = environmentsRegistry.getEnvironmentVariables envName;
  
    # Get environment resources
    resources = environmentsRegistry.getEnvironmentResources envName;
  
    # Get environment services
    services = environmentsRegistry.getEnvironmentServices envName;
  
    # Create environment-specific runner script
    envRunnerScript = ''
      #!/usr/bin/env bash
      set -e
    
      # Set environment name
      export ENVIRONMENT="${envName}"
    
      # Set environment variables
      ${l.concatMapStrings (name: "export ${name}=\"${envVars.${name}}\"\n") 
        (l.attrNames envVars)}
    
      echo "🟢 Running pipeline ${pipeline.name} in ${envName} environment"
    
      # Apply resource limits if specified
      ${l.optionalString (resources ? cpu) ''
        export CPU_LIMIT="${resources.cpu}"
        echo "  CPU limit: ${resources.cpu}"
      ''}
      ${l.optionalString (resources ? memory) ''
        export MEMORY_LIMIT="${resources.memory}"
        echo "  Memory limit: ${resources.memory}"
      ''}
    
      # Override service endpoints if specified
      ${l.concatMapStrings (name: ''
        export ${name}_URL="${services.${name}}"
        echo "  Service ${name}: ${services.${name}}"
      '') (l.attrNames services)}
    
      # Execute the original runner with environment context
      ${runnerDrv}/bin/run-${pipeline.name} "$@"
    '';
  
    # Create environment-specific runner derivation
    envRunnerDrv = pkgs.writeScriptBin "run-${pipeline.name}-in-${envName}" envRunnerScript;
  in
    envRunnerDrv;

  # Create environment-specific runners for all environments
  environmentRunners = l.listToAttrs (
    l.map (envName: 
      l.nameValuePair 
        envName 
        (createEnvironmentAwareRunner envName)
    ) environmentsRegistry.getEnvironmentNames
  );

  # Create a runner that accepts an environment argument
  environmentSelectableRunnerScript = ''
    #!/usr/bin/env bash
    set -e
  
    # Default to dev environment if not specified
    ENVIRONMENT="dev"
  
    # Parse command line arguments
    ARGS=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --environment=*)
          ENVIRONMENT="''${1#*=}"
          shift
          ;;
        --environment)
          ENVIRONMENT="$2"
          shift 2
          ;;
        *)
          ARGS+=("$1")
          shift
          ;;
      esac
    done
  
    # Check if the environment exists
    if [[ ! -f "${pkgs.stdenv.mkDerivation {
      name = "environment-runners";
      phases = ["installPhase"];
      installPhase = ''
        mkdir -p $out/bin
        ${l.concatMapStrings (envName: ''
          touch $out/bin/${envName}
        '') environmentsRegistry.getEnvironmentNames}
      '';
    }}/bin/$ENVIRONMENT" ]]; then
      echo "Error: Environment '$ENVIRONMENT' not found"
      echo "Available environments: ${l.concatStringsSep ", " environmentsRegistry.getEnvironmentNames}"
      exit 1
    fi
  
    # Run the pipeline with the selected environment
    exec ${pkgs.stdenv.mkDerivation {
      name = "environment-runner-selector";
      phases = ["installPhase"];
      installPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/select-environment <<EOF
        #!/usr/bin/env bash
        case "\$ENVIRONMENT" in
        ${l.concatMapStrings (envName: ''
          ${envName})
            exec ${environmentRunners.${envName}}/bin/run-${pipeline.name}-in-${envName} "\$@"
            ;;
        '') environmentsRegistry.getEnvironmentNames}
        esac
        EOF
        chmod +x $out/bin/select-environment
      '';
    }}/bin/select-environment "''${ARGS[@]}"
  '';

  # Create environment-selectable runner derivation
  environmentSelectableRunnerDrv = pkgs.writeScriptBin "run-${pipeline.name}-with-env" environmentSelectableRunnerScript;

  # Add environment support to the pipeline configuration
  pipelineWithEnvironments = {
    # Original pipeline data
    inherit (pipeline) name system steps services inputs outputs resources description;
  
    # Enhanced outputs
    mermaidDiagram = mermaidDiagram;
    runner = runnerDrv;
  
    # Add environment-specific runners
    environmentRunners = environmentRunners;
    environmentSelectableRunner = environmentSelectableRunnerDrv;
  
    # Add metadata for pipeline execution
    metadata = pipeline.metadata or {};
  };

  # Add to the existing transformer to support model registration

  # Function to register a model from a pipeline
  registerModel = {
    name,
    version,
    framework,
    artifact,
    metrics ? {},
    lineage ? {},
    description ? "",
  }: let
    # Create a model registration script
    registrationScript = ''
      #!/usr/bin/env bash
      set -e
      
      echo "Registering model: ${name} (version ${version})"
      
      # Create model definition file
      mkdir -p ./cells/model-registry/${pipeline.name}
      cat > ./cells/model-registry/${pipeline.name}/${name}.nix << EOF
      {
        inputs,
        cell,
      }: {
        name = "${name}";
        version = "${version}";
        framework = "${framework}";
        pipeline = "${pipeline.name}";
        description = "${description}";
        
        # Path to the model artifact
        artifact = "${artifact}";
        
        # Performance metrics
        metrics = ${builtins.toJSON metrics};
        
        # Lineage information
        lineage = ${builtins.toJSON (lineage // {
          training_pipeline = pipeline.name;
          training_date = "$(date -Iseconds)";
        })};
      }
      EOF
      
      echo "Model registered successfully!"
    '';
    
    # Create registration script derivation
    registrationDrv = pkgs.writeScriptBin "register-model-${name}-${version}" registrationScript;
  in
    registrationDrv;

  # Add model registration step to pipeline steps
  pipelineWithModelRegistration = {
    inherit (pipeline) name system description;
    
    # Original pipeline attributes
    inputs = pipeline.inputs or [];
    outputs = pipeline.outputs or [];
    services = pipeline.services or [];
    resources = pipeline.resources or {};
    steps = pipeline.steps;
    
    # Add model registration capability
    registerModel = registerModel;
    
    # Add metadata
    metadata = pipeline.metadata or {};
  };

in {
  # Original pipeline data
  inherit (pipeline) name system steps services inputs outputs resources description;
  
  # Enhanced outputs
  mermaidDiagram = mermaidDiagram;
  runner = runnerDrv;
  
  # Add metadata for pipeline execution
  metadata = pipeline.metadata or {};
  
  # Generate an uber pipeline configuration that combines multiple pipeline configurations
  generateUberPipelineConfiguration = allPipelineConfigurations: let
    names = l.attrNames allPipelineConfigurations;
    
    # Create a combined pipeline configuration
    uberPipelineConfiguration = {
      type = "pipelineConfiguration";
      name = "uber-pipeline";
      system = "x86_64-linux";
      description = "Serial execution of all pipeline configurations: ${l.concatStringsSep ", " names}";
      
      # Combine all inputs and outputs
      inputs = l.concatMap (name: allPipelineConfigurations.${name}.inputs or []) names;
      outputs = l.concatMap (name: allPipelineConfigurations.${name}.outputs or []) names;
      
      # Combine all services
      services = l.unique (l.concatMap (name: allPipelineConfigurations.${name}.services or []) names);
      
      # Combine all resources (taking maximum values)
      resources = l.foldl' (acc: name:
        let res = allPipelineConfigurations.${name}.resources or {}; in
        l.mapAttrs (k: v:
          if l.hasAttr k acc then
            if v > acc.${k} then v else acc.${k}
          else v
        ) (acc // res)
      ) {} names;
      
      # Create steps that run each pipeline in sequence
      steps = l.imap0 (i: name: {
        name = "run-${name}";
        command = "nix run .#run-${name}";
        depends = if i == 0 then [] else ["run-${l.elemAt names (i - 1)}"];
      }) names;
      
      # Combined metadata
      metadata = {
        description = "Combined execution of all pipeline configurations";
        tags = l.unique (l.concatMap (name: 
          allPipelineConfigurations.${name}.metadata.tags or []
        ) names);
      };
    };
    
    # Process the uber pipeline configuration through the transformer
    processedUberPipeline = root.transformers.pipelinesConfigurations uberPipelineConfiguration;
    
  in processedUberPipeline;
}
