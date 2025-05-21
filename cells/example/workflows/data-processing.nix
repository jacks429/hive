{
  inputs,
  cell,
}: {
  name = "data-processing";
  system = "x86_64-linux";
  description = "End-to-end data processing workflow from ingestion to visualization";
  
  # List of pipelines to execute
  pipelines = [
    "data-ingest"
    "data-clean"
    "data-transform"
    "taxonomy-classification" # New pipeline for classification using taxonomies
    "data-validate"
    "model-train"
    "model-evaluate"
    "model-deploy"
    "dashboard-generate"
  ];
  
  # Dependencies between pipelines (DAG structure)
  dependencies = {
    "data-ingest" = [];  # No dependencies, runs first
    "data-clean" = ["data-ingest"];  # Depends on ingestion
    "data-transform" = ["data-clean"];  # Depends on cleaning
    "taxonomy-classification" = ["data-transform"]; # Depends on transformed data
    "data-validate" = ["taxonomy-classification"]; # Now depends on classification
    "model-train" = ["data-validate"];  # Depends on validated data
    "model-evaluate" = ["model-train"];  # Depends on trained model
    "model-deploy" = ["model-evaluate"];  # Depends on evaluated model
    "dashboard-generate" = ["model-deploy", "data-validate"];  # Depends on deployed model and validated data
  };
  
  # Schedule information
  schedule = {
    cronExpression = "0 2 * * *";  # Every day at 2 AM
    timezone = "UTC";
  };
  
  # Resource requirements
  resources = {
    cpu = 8;
    memory = "16Gi";
    gpu = 1;
    storage = "50Gi";
  };
  
  # Notification configuration
  notifications = {
    onStart = ["slack:data-team-channel"];
    onSuccess = ["email:data-team@example.com", "slack:data-team-channel"];
    onFailure = ["email:data-team@example.com", "slack:data-team-alerts", "pagerduty:data-oncall"];
    includeDetails = true;
    attachLogs = true;
  };
  
  # Timeout configuration
  timeout = {
    workflow = "8h";  # Total workflow timeout
    pipelines = {
      "model-train" = "4h";  # Specific pipeline timeout
      "model-evaluate" = "2h";
    };
  };
  
  # Environment configuration
  environment = "production";
  
  # Tags for organization
  tags = ["data-processing", "ml", "production"];
}
