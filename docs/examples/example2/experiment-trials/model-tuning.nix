{
  inputs,
  cell,
}: {
  name = "model-tuning";
  description = "Hyperparameter tuning experiment for the ML model";
  
  # Reference to the pipeline to run
  pipeline = "model-train";
  pipelineCell = "example";
  
  # Parameter grid definition
  parameterGrid = {
    learning_rate = [0.001 0.01 0.1];
    batch_size = [32 64 128];
    epochs = [10 20 50];
    dropout = [0.1 0.3 0.5];
  };
  
  # Metrics to track
  metrics = [
    {
      name = "accuracy";
      path = "results/metrics.json";
      extract = "jq -r '.accuracy' results/metrics.json";
      description = "Model accuracy on validation set";
      direction = "maximize";  # Higher is better
    }
    {
      name = "loss";
      path = "results/metrics.json";
      extract = "jq -r '.loss' results/metrics.json";
      description = "Model loss on validation set";
      direction = "minimize";  # Lower is better
    }
    {
      name = "training_time";
      path = "results/metrics.json";
      extract = "jq -r '.training_time' results/metrics.json";
      description = "Training time in seconds";
      direction = "minimize";  # Lower is better
    }
  ];
  
  # Output configuration
  outputPath = "./results/model-tuning";
  
  # Trial selection strategy
  strategy = "grid";  # grid, random, bayesian
  
  # Early stopping criteria
  earlyStoppingConfig = {
    metric = "accuracy";
    threshold = 0.95;
    direction = "maximize";  # Stop if accuracy exceeds 0.95
  };
  
  # System information
  system = "x86_64-linux";
}