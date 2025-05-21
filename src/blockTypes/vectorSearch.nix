# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{
  # Vector search configuration
  name = {
    type = "string";
    description = "Name of the vector search";
  };
  description = {
    type = "string";
    description = "Description of the vector search";
  };
  collection = {
    type = "string";
    description = "Vector collection to search";
  };
  index = {
    type = "attrs";
    description = "Index configuration";
  };
  metric = {
    type = "string";
    description = "Distance metric to use (e.g., cosine, euclidean, dot)";
  };
  parameters = {
    type = "attrs";
    description = "Search parameters";
  };
  system = {
    type = "string";
    description = "System architecture for the vector search";
  };
}
