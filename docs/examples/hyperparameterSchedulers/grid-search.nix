{
  inputs,
  cell,
}: {
  name = "grid-search";
  description = "Grid search for hyperparameter optimization";
  
  type = "grid";
  
  parameters = [
    "learning_rate"
    "batch_size"
    "dropout"
  ];
  
  searchSpace = {
    learning_rate = {
      type = "float";
      min = 0.0001;
      max = 0.1;
      log = true;
    };
    batch_size = {
      type = "categorical";
      values = [16 32 64 128];
    };
    dropout = {
      type = "float";
      min = 0.1;
      max = 0.5;
      step = 0.1;
    };
  };
  
  objective = {
    metric = "validation_accuracy";
    direction = "maximize";
  };
  
  config = {
    maxTrials = 50;
    maxParallelTrials = 4;
    earlyStoppingRounds = 5;
  };
  
  # System information
  system = "x86_64-linux";
}