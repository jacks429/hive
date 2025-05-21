#!/usr/bin/env bash
# Script to create missing cell directories

# Create directories for all declared cell blocks
mkdir -p cells/deep-learning-models
mkdir -p cells/hyperparameter-schedulers
mkdir -p cells/explainability-techniques
mkdir -p cells/drift-detectors
mkdir -p cells/fairness-metrics
mkdir -p cells/model-compression
mkdir -p cells/adversarial-attacks
mkdir -p cells/interpretability-reports
mkdir -p cells/data-validators
mkdir -p cells/pipeline-monitors
mkdir -p cells/resource-profiles
mkdir -p cells/schema-evolution
mkdir -p cells/load-tests
mkdir -p cells/dataset-catalog
mkdir -p cells/vector-collections
mkdir -p cells/vector-queries
mkdir -p cells/vector-stores

# Add README files to each directory
for dir in cells/*/; do
  if [ ! -f "$dir/README.md" ]; then
    cell_name=$(basename "$dir")
    echo "# $cell_name" > "$dir/README.md"
    echo "" >> "$dir/README.md"
    echo "This directory contains configurations for the \`$cell_name\` cell block." >> "$dir/README.md"
  fi
done

echo "Created all missing cell directories with README files."
