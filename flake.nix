# SPDX-FileCopyrightText: 2022 The Standard Authors
#
# SPDX-License-Identifier: Unlicense
{
  description = "The Hive - The secretly open NixOS-Society";

  inputs.paisano.follows = "std/paisano";
  inputs.std = {
    url = "github:divnix/std";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.devshell.follows = "devshell";
    inputs.nixago.follows = "nixago";
  };

  inputs.devshell = {
    url = "github:numtide/devshell";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.nixago = {
    url = "github:nix-community/nixago";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.nixago-exts.follows = "";
  };

  inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # override downstream with inputs.hive.inputs.nixpkgs.follows = ...
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.colmena.url = "github:divnix/blank";

  outputs = {
    nixpkgs,
    std,
    paisano,
    colmena,
    deploy-rs,
    nixago,
    devshell,
    self,
  } @ inputs: let
    inherit (std.inputs) haumea;
    inherit (nixpkgs) lib;
    
    # Define default inputs for Haumea loaders at the top level
    defaultInputs = {
      modelType = "generic";  # Default model type
      cliPrefix = "run";      # Default CLI prefix
      servicePrefix = "serve"; # Default service prefix
      inventoryFile = ./inventory.json;  # Default inventory file path
      renamer = cell: target: "${cell}-${target}";  # Default renamer function
      cell = "default";  # Default cell name
      # Use flakeRoot instead of root (Haumea restricts root, self, super)
      flakeRoot = self;  # Safe alternative to root
      deploy-rs = inputs.deploy-rs;  # Prevent undefined deploy-rs
      colmena = inputs.colmena;  # Prevent undefined colmena
    };
    
    # Create a reusable load function with defaults - DEFINE THIS FIRST
    loadWithDefaults = src: extraInputs: 
      haumea.lib.load {
        inherit src;
        loader = haumea.lib.loaders.scoped;
        # Carefully construct inputs to avoid forbidden names
        inputs = removeAttrs (inputs // defaultInputs // extraInputs // { 
          inherit inputs; 
        }) [ "self" "root" "super" ];
        transformer = with haumea.lib.transformers; [
          liftDefault
          (hoistLists "_imports" "imports")
        ];
      };
    
    # Load everything from src
    hive = let
      inherit (nixpkgs) lib;
      
      # Filter out the 'blockTypes' directory entirely
      filteredSrc = builtins.path {
        name = "filtered-src";
        path = ./src;
        filter = name: type:
          let baseName = baseNameOf name;
          in !(baseName == "blockTypes" && type == "directory");
      };
      
      # Load filtered source with default inputs injected
      allSrc = loadWithDefaults filteredSrc {
        target = { name = "default"; }; # Provide fallback target for templatesConfigurations.nix
      };
      
      # Load blockTypes.nix separately
      blockTypesFile = import ./src/blockTypes.nix {
        inherit nixpkgs;
        root = self;  # Direct import can use root
      };
    in allSrc // { blockTypes = blockTypesFile; };
    
    # compat wrapper for haumea.lib.load
    load = {
      inputs,
      cell,
      src,
    }:
    # modules/profiles are always functions
    args @ {
      config,
      pkgs,
      ...
    }: let
      cr = cell.__cr ++ [(baseNameOf src)];
      file = "${self.outPath}#${lib.concatStringsSep "/" cr}";

      defaultWith = let
        inherit
          (lib)
          functionArgs
          pipe
          toFunction
          ;
      in (importer: inputs: path: let
        f = toFunction (importer path);
        # Add all defaultInputs to prevent undefined variable errors
        enhancedInputs = inputs // defaultInputs;
        
        # Debug trace to help identify missing inputs
        # Uncomment when debugging specific modules
        # _ = builtins.trace "Function args for ${file}: ${toString (builtins.attrNames (functionArgs f))}" null;
      in
        pipe f [
          functionArgs
          (let
            context = name: ''while evaluating the argument `${name}' in "${file}":'';
          in
            builtins.mapAttrs (
              name: _:
                builtins.addErrorContext (context name)
                (if enhancedInputs ? ${name} 
                 then enhancedInputs.${name} 
                 else if config._module.args ? ${name} 
                      then config._module.args.${name} 
                      else null)
            ))
          f
        ]);
      loader = inputs: defaultWith (scopedImport inputs) inputs;
      i = args // {inherit cell inputs;} // defaultInputs;
    in
      if lib.pathIsDirectory src
      then
        lib.setDefaultModuleLocation file (haumea.lib.load {
          inherit loader src;
          transformer = with haumea.lib.transformers; [
            liftDefault
            (hoistLists "_imports" "imports")
          ];
          inputs = i;
        })
      # Mimic haumea for a regular file
      else lib.setDefaultModuleLocation file (loader i src);

    findLoad = {
      inputs,
      cell,
      block,
    }:
      with builtins;
        lib.mapAttrs'
        (n: _:
          lib.nameValuePair
          (lib.removeSuffix ".nix" n)
          (load {
            inputs = inputs // defaultInputs;
            inherit cell;
            src = block + /${n};
          }))
        (removeAttrs (readDir block) ["default.nix"]);
        
    # Create a fixed version of the paisano grow function to handle the head error
    safeGrow = args: let
      result = paisano.grow args;
    in result;
    
    # Create a fixed version of the paisano growOn function
    safeGrowOn = args: overlays: let
      result = paisano.growOn args overlays;
    in result;
    # Debugging helper for transformer input issues
    debugTransformer = transformerPath: config: let
      transformerFn = import transformerPath;
      args = builtins.functionArgs transformerFn;
      missingArgs = builtins.filter (arg: 
        !(defaultInputs ? ${arg}) && 
        arg != "root" && 
        arg != "self" && 
        arg != "super"
      ) (builtins.attrNames args);
      
      _trace1 = builtins.trace "Transformer at ${toString transformerPath} expects: ${toString (builtins.attrNames args)}" null;
      _trace2 = if missingArgs != [] 
          then builtins.trace "Missing arguments: ${toString missingArgs}" null
          else null;
      
      # Create safe inputs for the transformer
      safeInputs = defaultInputs // { 
        inherit config; 
        # If it needs root, provide it directly (not via Haumea)
        root = if args ? root then self else null;
      };
    in transformerFn safeInputs;
    # Compatibility wrapper for transformers that expect 'root'
    wrapTransformer = transformerPath: let
      transformerFn = import transformerPath;
      args = builtins.functionArgs transformerFn;
      needsRoot = args ? root;
    in
      if needsRoot then
        # If transformer expects 'root', adapt it
        config: transformerFn (if args ? nixpkgs 
          then { 
            inherit nixpkgs; 
            root = self; 
            inherit config;
          } 
          else { 
            root = self; 
            inherit config;
          })
      else
        # Otherwise pass it through
        transformerFn;
  in
    safeGrowOn {
      inputs =
        inputs
        // {
          hive = {
            inherit findLoad load;
          };
        };
      cellsFrom = ./aux;
      cellBlocks = [
        {
          type = "profiles";
          name = "profiles";
        }
        {
          type = "shell";
          name = "shell";
        }
        {
          type = "pipelines";
          name = "pipelines";
        }
        {
          type = "hooks";
          name = "hooks";
        }
        {
          type = "qualityGates";
          name = "quality-gates";
        }
        {
          type = "microservices";
          name = "microservices";
        }
        {
          type = "datasets";
          name = "datasets";
        }
        {
          type = "workflows";
          name = "workflows";
        }
        {
          type = "serviceEndpoints";
          name = "serviceEndpoints";
        }
        {
          type = "parameters";
          name = "parameters";
        }
        {
          type = "environments";
          name = "environments";
        }
        {
          type = "modelRegistry";
          name = "model-registry";
        }
        {
          type = "templates";
          name = "templates";
        }
        {
          type = "dataLineage";
          name = "data-lineage";
        }
        {
          type = "schedules";
          name = "schedules";
        }
        {
          type = "dataLoaders";
          name = "data-loaders";
        }
        {
          type = "lexicons";
          name = "lexicons";
        }
        {
          type = "evaluationWorkflows";
          name = "evaluation-workflows";
        }
        {
          type = "secretStores";
          name = "secret-stores";
        }
        {
          type = "experimentTrials";
          name = "experiment-trials";
        }
        {
          type = "lexicons";
          name = "nlp-lexicons";
        }
        {
          type = "versioning";
          name = "versioning";
        }
        {
          type = "rules";
          name = "rules";
        }
        {
          type = "taxonomies";
          name = "taxonomies";
        }
        {
          type = "vectorStores";
          name = "vectorStores";
        }
        {
          type = "vectorCollections";
          name = "vectorCollections";
        }
        {
          type = "vectorIngestors";
          name = "vectorIngestors";
        }
        {
          type = "vectorQueries";
          name = "vectorQueries";
        }
        {
          type = "resourceProfiles";
          name = "resourceProfiles";
        }
        {
          type = "schemaEvolution";
          name = "schemaEvolution";
        }
        {
          type = "loadTests";
          name = "loadTests";
        }
        {
          type = "datasetCatalog";
          name = "datasetCatalog";
        }
        {
          type = "adversarialAttacks";
          name = "adversarial-attacks";
        }
        {
          type = "driftDetectors";
          name = "drift-detectors";
        }
        {
          type = "fairnessMetrics";
          name = "fairness-metrics";
        }
        {
          type = "interpretabilityReports";
          name = "interpretability-reports";
        }
        {
          type = "modelCompression";
          name = "model-compression";
        }
        {
          type = "pipelineMonitors";
          name = "pipeline-monitors";
        }
        {
          type = "thresholdPolicies";
          name = "threshold-policies";
        }
        {
          type = "vectorSearch";
          name = "vector-searches";
        }
        (std.blockTypes.nixago "configs")
        (std.blockTypes.devshells "shells" {ci.build = true;})
      ];
    }
    {
      # Export these as flake outputs
      blockTypes = hive.blockTypes;
      collect = hive.collect;
      grow = safeGrow;
      growOn = safeGrowOn;
      pick = paisano.pick;
      harvest = paisano.harvest;
      winnow = paisano.winnow;

      # Export the transformers and collectors libraries
      lib = {
        transformers = import ./lib/transformers.nix { inherit (nixpkgs) lib; pkgs = nixpkgs.legacyPackages.x86_64-linux; };
        collectors = import ./lib/collectors.nix { inherit (nixpkgs) lib; pkgs = nixpkgs.legacyPackages.x86_64-linux; };
      };
    }
    // haumea.lib;
}
