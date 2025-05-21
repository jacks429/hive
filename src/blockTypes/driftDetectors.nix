# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Drift detector configuration
  name = {
    type = "string";
    description = "Name of the drift detector";
  };
  description = {
    type = "string";
    description = "Description of the drift detector";
  };
  method = {
    type = "string";
    description = "Method used for drift detection (e.g., KS-test, MMD, Chi-squared)";
  };
  metrics = {
    type = "list";
    description = "List of metrics to monitor for drift";
  };
  thresholds = {
    type = "attrs";
    description = "Thresholds for each metric";
  };
  dataSource = {
    type = "attrs";
    description = "Data source configuration";
  };
  system = {
    type = "string";
    description = "System architecture for the drift detector";
  };
}
