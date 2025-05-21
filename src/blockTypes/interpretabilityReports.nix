# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Interpretability report configuration
  name = {
    type = "string";
    description = "Name of the interpretability report";
  };
  description = {
    type = "string";
    description = "Description of the interpretability report";
  };
  model = {
    type = "attrs";
    description = "Model configuration";
  };
  methods = {
    type = "list";
    description = "List of interpretability methods to apply (e.g., LIME, SHAP, feature importance)";
  };
  datasets = {
    type = "list";
    description = "List of datasets used for interpretation";
  };
  system = {
    type = "string";
    description = "System architecture for the interpretability report";
  };
}
