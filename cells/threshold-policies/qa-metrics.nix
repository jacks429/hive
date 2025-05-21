{
  inputs,
  cell,
}: {
  name = "qa-metrics";
  description = "Threshold policies for QA models";
  
  task = "qa-v1";
  
  thresholds = [
    {
      metric = "F1";
      min = 88.0;
      action = "fail";  # fail, warn, log
      message = "F1 score below minimum threshold";
    }
    {
      metric = "EM";
      min = 80.0;
      action = "warn";
      message = "Exact match score below minimum threshold";
    }
    {
      metric = "latency_ms";
      max = 50.0;
      action = "fail";
      message = "Latency exceeds maximum threshold";
    }
  ];
  
  # Optional slice-specific thresholds
  slices = {
    "en-us" = [
      {
        metric = "F1";
        min = 90.0;
        action = "warn";
      }
    ];
    "short-questions" = [
      {
        metric = "F1";
        min = 92.0;
        action = "log";
      }
    ];
  };
  
  # System information
  system = "x86_64-linux";
}