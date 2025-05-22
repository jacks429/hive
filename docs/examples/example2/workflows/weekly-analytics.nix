{
  inputs,
  cell,
}: {
  name = "weekly-analytics";
  system = "x86_64-linux";
  description = "Weekly analytics workflow that runs data aggregation and report generation";
  
  # List of pipelines to execute
  pipelines = [
    "data-aggregate"
    "metrics-calculate"
    "anomaly-detect"
    "report-weekly"
    "dashboard-update"
  ];
  
  # Dependencies between pipelines (DAG structure)
  dependencies = {
    "data-aggregate" = [];  # No dependencies, runs first
    "metrics-calculate" = ["data-aggregate"];  # Depends on aggregate
    "anomaly-detect" = ["metrics-calculate"];  # Depends on metrics
    "report-weekly" = ["metrics-calculate" "anomaly-detect"];  # Depends on both metrics and anomalies
    "dashboard-update" = ["report-weekly"];  # Depends on report
  };
  
  # Schedule information
  schedule = {
    cronExpression = "0 8 * * 1";  # Every Monday at 8 AM
    timezone = "UTC";
  };
  
  # Resource requirements
  resources = {
    cpu = 4;
    memory = "8Gi";
    storage = "20Gi";
  };
  
  # Notification configuration
  notifications = {
    onSuccess = ["email:analytics-team@example.com"];
    onFailure = ["email:analytics-team@example.com", "slack:analytics-alerts"];
    includeDetails = true;
  };
}
