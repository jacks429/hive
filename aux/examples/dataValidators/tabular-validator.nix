{
  inputs,
  cell,
}: {
  name = "tabular-validator";
  description = "Data validation for tabular datasets";
  
  type = "great-expectations";
  
  dataSource = {
    type = "csv";
  };
  
  expectations = [
    {
      type = "expect_column_to_exist";
      column = "user_id";
    }
    {
      type = "expect_column_values_to_not_be_null";
      column = "user_id";
    }
    {
      type = "expect_column_values_to_be_unique";
      column = "user_id";
    }
    {
      type = "expect_column_values_to_be_of_type";
      column = "age";
      type_list = ["int" "float"];
    }
    {
      type = "expect_column_values_to_be_between";
      column = "age";
      min_value = 0;
      max_value = 120;
    }
    {
      type = "expect_column_values_to_be_in_set";
      column = "gender";
      value_set = ["M" "F" "Other" "Prefer not to say"];
    }
  ];
  
  rules = [
    {
      name = "missing_values";
      description = "Check for missing values";
      threshold = 0.1; # Maximum 10% missing values allowed
    }
    {
      name = "outliers";
      description = "Check for outliers";
      columns = ["age" "income"];
      method = "iqr";
      factor = 1.5;
    }
  ];
  
  onFailure = {
    action = "fail"; # Options: "fail", "warn", "alert"
    alertChannels = ["email" "slack"];
  };
  
  # System information
  system = "x86_64-linux";
}