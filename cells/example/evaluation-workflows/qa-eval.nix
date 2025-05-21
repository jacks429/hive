{
  inputs,
  cell,
}: {
  name = "qa-evaluation";
  description = "End-to-end evaluation workflow for QA model performance";
  
  # Data loading stage
  dataLoader = "example-data-loaders-qa-dataset";
  dataLoaderParams = {
    splitRatio = 0.2;  # Use 20% for evaluation
    randomSeed = 42;
  };
  
  # Model/pipeline stage
  model = "example-pipelines-text-analysis";
  modelParams = {
    batchSize = 16;
    maxLength = 512;
  };
  modelOutput = "./qa-model-predictions.json";
  
  # Reference data for evaluation
  referenceData = "./qa-reference-answers.json";
  
  # Evaluation metrics
  metrics = [
    "accuracy-metric"
    "f1-score-metric"
    "entity-recognition-metric"
  ];
  
  # System information
  system = "x86_64-linux";
}