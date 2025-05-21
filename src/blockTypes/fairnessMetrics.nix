# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Fairness metric configuration
  name = {
    type = "string";
    description = "Name of the fairness metric";
  };
  description = {
    type = "string";
    description = "Description of the fairness metric";
  };
  method = {
    type = "string";
    description = "Method used for fairness evaluation (e.g., demographic parity, equal opportunity)";
  };
  sensitiveAttributes = {
    type = "list";
    description = "List of sensitive attributes to evaluate for fairness";
  };
  thresholds = {
    type = "attrs";
    description = "Fairness thresholds for each attribute";
  };
  system = {
    type = "string";
    description = "System architecture for the fairness metric";
  };
}
