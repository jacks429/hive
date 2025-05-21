# Unreleased Changes

## Added

- Added `lib/transformers.nix` library for creating and manipulating transformers
  - Configuration handling functions: `withDefaults`, `validateConfig`
  - CLI argument parsing functions: `withArgs`, `parseArgs`
  - Documentation generation functions: `generateDocs`, `formatParams`
  - Derivation creation functions: `mkScript`, `mkDocs`, `mkPackage`
  - Block discovery and enumeration functions: `mapBlocks`, `filterBlocks`
  - Error handling functions: `withErrorHandling`
  - Result marshaling functions: `toJSON`, `fromJSON`
  - Helpers for specific transformer types: `mkModelTransformer`
- Added tests for the transformers library in `checks/transformers-tests.nix`
- Added documentation for the transformers library in `docs/transformers/README.md`

## Changed

- Refactored transformers to use the shared library:
  - `src/transformers/summarizers.nix`
  - `src/transformers/leaderboards.nix`
  - `src/transformers/vectorIngestors.nix`
  - `src/transformers/datasetCatalog.nix`
  - `src/transformers/deepLearningModels.nix`
  - `src/transformers/resourceProfiles.nix`
  - `src/transformers/vectorQueries.nix`
  - `src/transformers/baselineResults.nix`
  - `src/transformers/loadTests.nix`
  - `src/transformers/schemaEvolution.nix`
  - `src/transformers/vectorCollections.nix`
  - `src/transformers/genericModel.nix`
  - `src/transformers/notebooks.nix`
  - `src/transformers/taxonomyDocs.nix`
- Updated flake.nix to export the transformers library

## Fixed

- Fixed inconsistent CLI argument parsing across transformers
- Fixed duplicated documentation generation code
- Fixed inconsistent error handling in transformers
