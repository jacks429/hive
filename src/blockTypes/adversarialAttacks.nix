# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Adversarial attack configuration
  name = {
    type = "string";
    description = "Name of the adversarial attack";
  };
  description = {
    type = "string";
    description = "Description of the adversarial attack";
  };
  method = {
    type = "string";
    description = "Method used for the adversarial attack (e.g., FGSM, PGD, CW)";
  };
  parameters = {
    type = "attrs";
    description = "Parameters for the adversarial attack method";
  };
  target = {
    type = "attrs";
    description = "Target model configuration";
  };
  system = {
    type = "string";
    description = "System architecture for the adversarial attack";
  };
}
