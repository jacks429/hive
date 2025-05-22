{
  nixpkgs,
  root,
}: {
  # Configurations
  nixosConfigurations = import ./blockTypes/nixosConfigurations.nix {
    inherit nixpkgs root;
  };
  darwinConfigurations = import ./blockTypes/darwinConfigurations.nix {
    inherit nixpkgs root;
  };
  homeConfigurations = import ./blockTypes/homeConfigurations.nix {
    inherit nixpkgs root;
  };
  colmenaConfigurations = import ./blockTypes/colmenaConfigurations.nix {
    inherit nixpkgs root;
  };
  deployrsConfigurations = import ./blockTypes/deployrsConfigurations.nix {
    inherit nixpkgs root;
  };
  
  # Data and ML
  pipelines = import ./blockTypes/pipelines.nix {
    inherit nixpkgs root;
  };
  datasets = import ./blockTypes/datasets.nix {
    inherit nixpkgs root;
  };
  modelRegistry = import ./blockTypes/modelRegistry.nix {
    inherit nixpkgs root;
  };
  dataLineage = import ./blockTypes/dataLineage.nix {
    inherit nixpkgs root;
  };
  dataLoaders = import ./blockTypes/dataLoaders.nix {
    inherit nixpkgs root;
  };
  lexicons = import ./blockTypes/lexicons.nix {
    inherit nixpkgs root;
  };
  
  # Orchestration
  workflows = import ./blockTypes/workflows.nix {
    inherit nixpkgs root;
  };
  schedules = import ./blockTypes/schedules.nix {
    inherit nixpkgs root;
  };
  
  # Security
  secretStores = import ./blockTypes/secretStores.nix {
    inherit nixpkgs root;
  };
  
  # Services
  microservices = import ./blockTypes/microservices.nix {
    inherit nixpkgs root;
  };
  serviceEndpoints = import ./blockTypes/serviceEndpoints.nix {
    inherit nixpkgs root;
  };
  
  # Configuration
  parameters = import ./blockTypes/parameters.nix {
    inherit nixpkgs root;
  };
  environments = import ./blockTypes/environments.nix {
    inherit nixpkgs root;
  };
  
  # Quality
  qualityGates = import ./blockTypes/qualityGates.nix {
    inherit nixpkgs root;
  };
  
  # Templates
  templates = import ./blockTypes/templates.nix {
    inherit nixpkgs root;
  };
  # Add versioning block type here
  versioning = import ./blockTypes/versioning.nix {
    inherit nixpkgs root;
  };

  # New block types for resource management and testing
  resourceProfiles = import ./blockTypes/resourceProfiles.nix {
    inherit nixpkgs root;
  };
  schemaEvolution = import ./blockTypes/schemaEvolution.nix {
    inherit nixpkgs root;
  };
  loadTests = import ./blockTypes/loadTests.nix {
    inherit nixpkgs root;
  };
  datasetCatalog = import ./blockTypes/datasetCatalog.nix {
    inherit nixpkgs root;
  };

  # Define block types for model-related blocks
  classifiers = import ./blockTypes/classifiers.nix {
    inherit nixpkgs root;
  };
  
  deepLearningModels = import ./blockTypes/deepLearningModels.nix {
    inherit nixpkgs root;
  };
  
  embedders = import ./blockTypes/embedders.nix {
    inherit nixpkgs root;
  };
  
  topicModels = import ./blockTypes/topicModels.nix {
    inherit nixpkgs root;
  };

  # Add this to the existing blockTypes.nix file
  sentimentAnalyzers = import ./blockTypes/sentimentAnalyzers.nix {
    inherit nixpkgs root;
  };

  # Generic model types with explicit modelType
  genericModel = modelType: name: {
    name = name;
    modelType = modelType;
    description = "${modelType} models";
    
    collector = import ./collectors/genericModel.nix {
      inherit nixpkgs;
      inputs = root;
      cell = null;
      modelType = modelType; # Explicitly pass modelType
    };
    
    transformer = config: import ./transformers/genericModel.nix {
      inherit nixpkgs root;
      inputs = root;
      modelType = modelType; # Explicitly pass modelType
    } (config // { modelType = modelType; }); # Ensure config has modelType
  };
  
  # Add specific model types that aren't already defined above
  summarizers = import ./blockTypes/summarizers.nix {
    inherit nixpkgs root;
  };
  
  # Other block types
  nixago = import ./blockTypes/nixago.nix;
  devshells = import ./blockTypes/devshells.nix;
}
