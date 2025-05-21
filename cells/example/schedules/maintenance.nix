{
  inputs,
  cell,
}: {
  name = "maintenance-schedule";
  description = "Schedule for system maintenance tasks";
  
  jobs = [
    {
      name = "backup-database";
      description = "Backup all databases";
      command = "nix run .#backup-databases";
      cronExpression = "0 1 * * *"; # Every day at 1 AM
      hour = "1";
      minute = "0";
      user = "backup";
      tags = ["backup" "daily"];
    }
    {
      name = "cleanup-logs";
      description = "Clean up old log files";
      command = "nix run .#cleanup-logs";
      cronExpression = "0 2 * * 0"; # Every Sunday at 2 AM
      hour = "2";
      minute = "0";
      weekday = "0";
      user = "system";
      tags = ["cleanup" "weekly"];
    }
    {
      name = "update-packages";
      description = "Update system packages";
      command = "nix run .#update-packages";
      cronExpression = "0 3 1 * *"; # First day of month at 3 AM
      hour = "3";
      minute = "0";
      day = "1";
      user = "system";
      tags = ["update" "monthly"];
    }
    {
      name = "security-scan";
      description = "Run security vulnerability scan";
      command = "nix run .#security-scan";
      cronExpression = "0 4 * * 1"; # Every Monday at 4 AM
      hour = "4";
      minute = "0";
      weekday = "1";
      user = "security";
      tags = ["security" "weekly"];
    }
  ];
}