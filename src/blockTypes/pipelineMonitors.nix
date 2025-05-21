# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Pipeline monitor configuration
  name = {
    type = "string";
    description = "Name of the pipeline monitor";
  };
  description = {
    type = "string";
    description = "Description of the pipeline monitor";
  };
  pipeline = {
    type = "attrs";
    description = "Pipeline configuration";
  };
  metrics = {
    type = "list";
    description = "List of metrics to monitor (e.g., latency, throughput, error rate)";
  };
  alerts = {
    type = "list";
    description = "List of alert configurations";
  };
  schedule = {
    type = "attrs";
    description = "Monitoring schedule configuration";
  };
  system = {
    type = "string";
    description = "System architecture for the pipeline monitor";
  };
}
