{
  nixpkgs,
  root,
}: {
  # Configurations
  nixosConfigurations = import ./transformers/nixosConfigurations.nix {
    inherit nixpkgs root;
  };
  darwinConfigurations = import ./transformers/darwinConfigurations.nix {
    inherit nixpkgs root;
  };
  homeConfigurations = import ./transformers/homeConfigurations.nix {
    inherit nixpkgs root;
  };
  colmenaConfigurations = import ./transformers/colmenaConfigurations.nix {
    inherit nixpkgs root;
  };
  deployrsConfigurations = import ./transformers/deployrsConfigurations.nix {
    inherit nixpkgs root;
  };

  # Data and ML
  pipelines = import ./transformers/pipelines.nix {
    inherit nixpkgs root;
  };
  pipelinesConfigurations = import ./transformers/pipelinesConfigurations.nix {
    inherit nixpkgs root;
  };
  datasets = import ./transformers/datasets.nix {
    inherit nixpkgs root;
  };
  modelRegistry = import ./transformers/modelRegistry.nix {
    inherit nixpkgs root;
  };
  modelRegistryConfigurations = import ./transformers/modelRegistryConfigurations.nix {
    inherit nixpkgs root;
  };
  dataLineage = import ./transformers/dataLineage.nix {
    inherit nixpkgs root;
  };
  dataLoaders = import ./transformers/dataLoaders.nix {
    inherit nixpkgs root;
  };
  dataLoadersConfigurations = import ./transformers/dataLoadersConfigurations.nix {
    inherit nixpkgs root;
  };
  lexicons = import ./transformers/lexicons.nix {
    inherit nixpkgs root;
  };
  evaluationWorkflows = import ./transformers/evaluationWorkflows.nix {
    inherit nixpkgs root;
  };
  evaluationWorkflowsConfigurations = import ./transformers/evaluationWorkflowsConfigurations.nix {
    inherit nixpkgs root;
  };

  # NLP/ML model transformers
  summarizers = import ./transformers/summarizers.nix {
    inherit nixpkgs root;
  };
  sentimentAnalyzers = import ./transformers/sentimentAnalyzers.nix {
    inherit nixpkgs root;
  };
  topicModels = import ./transformers/topicModels.nix {
    inherit nixpkgs root;
  };
  ocrModels = import ./transformers/ocrModels.nix {
    inherit nixpkgs root;
  };
  corefResolvers = import ./transformers/corefResolvers.nix {
    inherit nixpkgs root;
  };
  paraphrasers = import ./transformers/paraphrasers.nix {
    inherit nixpkgs root;
  };
  simplifiers = import ./transformers/simplifiers.nix {
    inherit nixpkgs root;
  };
  embeddingServices = import ./transformers/embeddingServices.nix {
    inherit nixpkgs root;
  };
  translationModels = import ./transformers/translationModels.nix {
    inherit nixpkgs root;
  };
  languageDetectors = import ./transformers/languageDetectors.nix {
    inherit nixpkgs root;
  };
  textGenerators = import ./transformers/textGenerators.nix {
    inherit nixpkgs root;
  };
  speechTranscribers = import ./transformers/speechTranscribers.nix {
    inherit nixpkgs root;
  };
  qaSystems = import ./transformers/qaSystems.nix {
    inherit nixpkgs root;
  };
  dataAugmenters = import ./transformers/dataAugmenters.nix {
    inherit nixpkgs root;
  };
  knowledgeExtractors = import ./transformers/knowledgeExtractors.nix {
    inherit nixpkgs root;
  };
  entityLinkers = import ./transformers/entityLinkers.nix {
    inherit nixpkgs root;
  };

  # Orchestration
  workflows = import ./transformers/workflows.nix {
    inherit nixpkgs root;
  };
  workflowsConfigurations = import ./transformers/workflowsConfigurations.nix {
    inherit nixpkgs root;
  };
  schedules = import ./transformers/schedules.nix {
    inherit nixpkgs root;
  };

  # Security
  secretStores = import ./transformers/secretStores.nix {
    inherit nixpkgs root;
  };

  # Services
  microservices = import ./transformers/microservices.nix {
    inherit nixpkgs root;
  };
  serviceEndpoints = import ./transformers/serviceEndpoints.nix {
    inherit nixpkgs root;
  };

  # Configuration
  parameters = import ./transformers/parameters.nix {
    inherit nixpkgs root;
  };
  environments = import ./transformers/environments.nix {
    inherit nixpkgs root;
  };

  # Quality
  qualityGates = import ./transformers/qualityGates.nix {
    inherit nixpkgs root;
  };

  # Templates
  templates = import ./transformers/templates.nix {
    inherit nixpkgs root;
  };
  versioning = import ./transformers/versioning.nix {
    inherit nixpkgs root;
  };

  # Documentation
  taxonomyDocs = import ./transformers/taxonomyDocs.nix {
    inherit nixpkgs root;
  };

  # Leaderboards and evaluation
  leaderboards = import ./transformers/leaderboards.nix {
    inherit nixpkgs root;
  };
  baselineResults = import ./transformers/baselineResults.nix {
    inherit nixpkgs root;
  };

  # Data catalog and management
  datasetCatalog = import ./transformers/datasetCatalog.nix {
    inherit nixpkgs root;
  };

  # Resource management
  resourceProfiles = import ./transformers/resourceProfiles.nix {
    inherit nixpkgs root;
  };

  # Schema management
  schemaEvolution = import ./transformers/schemaEvolution.nix {
    inherit nixpkgs root;
  };

  # Testing
  loadTests = import ./transformers/loadTests.nix {
    inherit nixpkgs root;
  };

  # Vector search
  vectorCollections = import ./transformers/vectorCollections.nix {
    inherit nixpkgs root;
  };
  vectorQueries = import ./transformers/vectorQueries.nix {
    inherit nixpkgs root;
  };

  # ML-ops transformers
  adversarialAttacks = import ./transformers/adversarialAttacks.nix {
    inherit nixpkgs root;
  };
  driftDetectors = import ./transformers/driftDetectors.nix {
    inherit nixpkgs root;
  };
  fairnessMetrics = import ./transformers/fairnessMetrics.nix {
    inherit nixpkgs root;
  };
  interpretabilityReports = import ./transformers/interpretabilityReports.nix {
    inherit nixpkgs root;
  };
  modelCompression = import ./transformers/modelCompression.nix {
    inherit nixpkgs root;
  };
  pipelineMonitors = import ./transformers/pipelineMonitors.nix {
    inherit nixpkgs root;
  };
  thresholdPolicies = import ./transformers/thresholdPolicies.nix {
    inherit nixpkgs root;
  };
}
