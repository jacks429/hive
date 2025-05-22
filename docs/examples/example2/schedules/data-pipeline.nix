{
  inputs,
  cell,
}: {
  name = "data-pipeline-schedule";
  description = "Schedule for running data pipeline jobs";
  
  jobs = [
    {
      name = "data-ingestion";
      description = "Ingest data from external sources";
      command = "nix run .#run-data-ingestion";
      cronExpression = "0 1 * * *"; # Every day at 1 AM
      hour = "1";
      minute = "0";
      user = "data-pipeline";
      tags = ["ingestion" "daily"];
    }
    {
      name = "data-processing";
      description = "Process and transform ingested data";
      command = "nix run .#run-data-processing";
      cronExpression = "0 3 * * *"; # Every day at 3 AM
      hour = "3";
      minute = "0";
      user = "data-pipeline";
      dependencies = ["data-ingestion"];
      tags = ["processing" "daily"];
    }
    {
      name = "data-export";
      description = "Export processed data to data warehouse";
      command = "nix run .#run-data-export";
      cronExpression = "0 5 * * *"; # Every day at 5 AM
      hour = "5";
      minute = "0";
      user = "data-pipeline";
      dependencies = ["data-processing"];
      tags = ["export" "daily"];
    }
    {
      name = "weekly-report";
      description = "Generate weekly data quality report";
      command = "nix run .#run-weekly-report";
      cronExpression = "0 8 * * 1"; # Every Monday at 8 AM
      hour = "8";
      minute = "0";
      weekday = "1";
      user = "data-pipeline";
      tags = ["report" "weekly"];
      
      # Systemd-specific options
      persistent = true;
      randomDelay = 300; # 5 minutes random delay
      
      # GitHub Actions-specific options
      runsOn = "self-hosted";
    }
  ];
}