{
  inputs,
  nixpkgs,
  root,
}: let
  collectors =
    root.collectors
    // {
      /*
      Modules declare an interface into a problem domain
      */
      darwinModules = throw "not implemented yet";
      nixosModules = throw "not implemented yet";
      homeModules = throw "not implemented yet";
      shellModules = throw "not implemented yet";
      /*
      Profiles define values on that interface
      */
      hardwareProfiles = throw "not implemented yet";
      darwinProfiles = throw "not implemented yet";
      nixosProfiles = throw "not implemented yet";
      homeProfiles = throw "not implemented yet";
      shellProfiles = throw "not implemented yet";
      /*
      Suites aggregate profiles into groups
      */
      darwinSuites = throw "not implemented yet";
      nixosSuites = throw "not implemented yet";
      homeSuites = throw "not implemented yet";
      shellSuites = throw "not implemented yet";

      /*
      Configurations for deployment tools
      */
      deployrsConfigurations = root.collectors.deployrsConfigurations;

      /*
      Pipelines define CI/CD workflows
      */
      pipelines = root.collectors.pipelines;

      /*
      Microservices define deployable service units
      */
      microservices = root.collectors.microservices;
      datasets = root.collectors.datasetsConfigerations;
      datasetsRegistry = root.collectors.datasetsRegistryConfigeration;
      workflowsConfigurations = root.collectors.workflowsConfigurations;
      workflowsRegistry = root.collectors.workflowsRegistryConfiguration;
      serviceEndpointsConfigurations = root.collectors.serviceEndpointsConfigurations;
      serviceEndpointsRegistry = root.collectors.serviceEndpointsRegistryConfiguration;
      /*
      Parameters define configurable values for pipelines
      */
      parametersConfigurations = root.collectors.parametersConfigurations;
      parametersRegistry = root.collectors.parametersRegistry;
      /*
      Environments define named execution contexts with their own config overlays
      */
      environmentsConfigurations = root.collectors.environmentsConfigurations;
      environmentsRegistry = root.collectors.environmentsRegistry;
      /*
      Model Registry tracks trained model artifacts, versions, and metadata
      */
      modelRegistryConfigurations = root.collectors.modelRegistryConfigurations;
      modelRegistryRegistry = root.collectors.modelRegistryRegistry;
      /*
      Templates define reusable patterns for pipelines and steps
      */
      templatesConfigurations = root.collectors.templatesConfigurations;
      templatesRegistry = root.collectors.templatesRegistry;
      /*
      Hooks for pipeline lifecycle events
      */
      hooks = import ./collectors/hooks.nix {
        inherit inputs nixpkgs root;
      };
      /*
      Quality Gates for pipeline validation
      */
      qualityGates = import ./collectors/qualityGates.nix {
        inherit inputs nixpkgs root;
      };
      /*
      Data Lineage tracks data transformations and dependencies
      */
      dataLineage = let
        collector = import ./collectors/dataLineage.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      dataLineageRegistry = let
        collector = import ./collectors/dataLineage.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.dataLineage or {});
      /*
      Schedules define when and how often jobs run
      */
      schedules = let
        collector = import ./collectors/schedules.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      schedulesRegistry = let
        collector = import ./collectors/schedules.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.schedules or {});
      /*
      Secret Stores manage sensitive information
      */
      secretStores = import ./collectors/secretStores.nix {
        inherit inputs nixpkgs root;
      };
      /*
      Workflows orchestrate multiple pipelines
      */
      workflows = let
        collector = import ./collectors/workflows.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      # Renamed to avoid conflict and better describe its purpose
      createWorkflowsRegistry = let
        collector = import ./collectors/workflows.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.workflows or {});
       /*
      Data Loaders fetch data from external sources
      */
      dataLoaders = let
        collector = import ./collectors/dataLoaders.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      dataLoadersRegistry = let
        collector = import ./collectors/dataLoaders.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.dataLoaders or {});
       # Add versioning collector here
      versioning = let
        collector = import ./collectors/versioning.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      versioningRegistry = let
        collector = import ./collectors/versioning.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.versioning or {});
      # Add lexicons collector here
      lexicons = let
        collector = import ./collectors/lexicons.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      lexiconsRegistry = let
        collector = import ./collectors/lexicons.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.lexicons or {});
      # Add rules collector here
      rules = let
        collector = import ./collectors/rules.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      rulesRegistry = let
        collector = import ./collectors/rules.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.rules or {});
      # Add leaderboards collector
      leaderboards = import ./collectors/leaderboards.nix {
        inherit inputs nixpkgs root;
      };

      # Add ML-ops collectors
      adversarialAttacks = let
        collector = import ./collectors/adversarialAttacks.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      adversarialAttacksRegistry = let
        collector = import ./collectors/adversarialAttacks.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.adversarialAttacks or {});
      driftDetectors = let
        collector = import ./collectors/driftDetectors.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      driftDetectorsRegistry = let
        collector = import ./collectors/driftDetectors.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.driftDetectors or {});
      fairnessMetrics = let
        collector = import ./collectors/fairnessMetrics.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      fairnessMetricsRegistry = let
        collector = import ./collectors/fairnessMetrics.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.fairnessMetrics or {});
      interpretabilityReports = let
        collector = import ./collectors/interpretabilityReports.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      interpretabilityReportsRegistry = let
        collector = import ./collectors/interpretabilityReports.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.interpretabilityReports or {});
      modelCompression = import ./collectors/modelCompression.nix {
        inherit inputs nixpkgs root;
      };
      pipelineMonitors = import ./collectors/pipelineMonitors.nix {
        inherit inputs nixpkgs root;
      };

      # Vector-related collectors
      vectorCollections = let
        collector = import ./collectors/vectorCollections.nix {
          inherit inputs nixpkgs root;
        };
      in collector.collector;

      # Vector-related registries
      vectorCollectionsRegistry = let
        collector = import ./collectors/vectorCollections.nix {
          inherit inputs nixpkgs root;
        };
      in self: collector.registry (self.vectorCollections or {});

      # Add model-related collectors
      classifiers = import ./collectors/classifiers.nix {
        inherit inputs nixpkgs root;
      };

      deepLearningModels = import ./collectors/deepLearningModels.nix {
        inherit inputs nixpkgs root;
      };

      embedders = import ./collectors/embedders.nix {
        inherit inputs nixpkgs root;
      };

      topicModels = import ./collectors/topicModels.nix {
        inherit inputs nixpkgs root;
      };
    };
in {
  renamer = cell: target: "${cell}-${target}";
  __functor = self: Self: CellBlock:
    if builtins.hasAttr CellBlock collectors
    then collectors.${CellBlock} self.renamer Self
    else
      builtins.throw ''

        `hive.collect` can't collect ${CellBlock}.

        It can collect the following cell blocks:
         - ${builtins.concatStringsSep "\n - " (builtins.attrNames collectors)}
      '';
}
