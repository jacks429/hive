{
  inputs,
  cell,
}: {
  name = "data-augmentation";
  description = "Experiment to evaluate different data augmentation strategies";
  
  # Reference to the pipeline to run
  pipeline = "data-transform";
  pipelineCell = "example";
  
  # Parameter grid definition
  parameterGrid = {
    rotation = [0 15 30];
    flip = [true false];
    zoom = [0.0 0.1 0.2];
    brightness = [0.0 0.1 0.2];
    noise = [0.0 0.05 0.1];
  };
  
  # Metrics to track
  metrics = [
    {
      name = "dataset_size";
      path = "results/dataset_metrics.json";
      extract = "jq -r '.size' results/dataset_metrics.json";
      description = "Size of the augmented dataset";
      direction = "maximize";
    }
    {
      name = "diversity_score";
      path = "results/dataset_metrics.json";
      extract = "jq -r '.diversity' results/dataset_metrics.json";
      description = "Diversity score of the augmented dataset";
      direction = "maximize";
    }
  ];
  
  # Output configuration
  outputPath = "./results/data-augmentation";
  
  # Trial selection strategy
  strategy = "random";
  maxTrials = 10;  # Only run 10 random combinations
  randomSeed = 42;
  
  # System information
  system = "x86_64-linux";
}