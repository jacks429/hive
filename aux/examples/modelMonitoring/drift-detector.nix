{
  inputs,
  cell,
}: {
  name = "drift-detector";
  description = "Monitor model inputs and outputs for data drift";
  
  type = "drift";
  
  models = [
    "image-classifier"
  ];
  
  metrics = [
    {
      name = "input_drift";
      type = "distribution";
      features = ["*"];
      reference = "training_data.csv";
      threshold = 0.05;
    }
    {
      name = "prediction_drift";
      type = "distribution";
      features = ["prediction"];
      reference = "training_predictions.csv";
      threshold = 0.05;
    }
    {
      name = "accuracy";
      type = "performance";
      threshold = 0.9;
    }
  ];
  
  schedule = {
    frequency = "hourly";
    retention = "30d";
  };
  
  alerts = {
    channels = ["email" "slack"];
    thresholds = {
      warning = 0.8;
      critical = 0.9;
    };
  };
  
  dashboard = {
    enable = true;
    port = 8050;
  };
  
  # System information
  system = "x86_64-linux";
}