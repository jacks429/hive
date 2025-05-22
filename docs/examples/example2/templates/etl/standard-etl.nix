{
  inputs,
  cell,
}: {
  name = "standard-etl";
  type = "pipeline";
  description = "Standard ETL pipeline template with extract, transform, and load steps";
  
  # Template parameters
  parameters = {
    name = {
      description = "Name of the pipeline";
      type = "string";
    };
  };
};
