# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Model compression configuration
  name = {
    type = "string";
    description = "Name of the model compression";
  };
  description = {
    type = "string";
    description = "Description of the model compression";
  };
  method = {
    type = "string";
    description = "Method used for model compression (e.g., quantization, pruning, knowledge distillation)";
  };
  sourceModel = {
    type = "attrs";
    description = "Source model configuration";
  };
  parameters = {
    type = "attrs";
    description = "Parameters for the compression method";
  };
  targetSize = {
    type = "string";
    description = "Target size for the compressed model (optional)";
  };
  system = {
    type = "string";
    description = "System architecture for the model compression";
  };
}
