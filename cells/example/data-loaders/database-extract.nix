{
  inputs,
  cell,
}: {
  name = "database-extract";
  system = "x86_64-linux";
  description = "Extract customer data from PostgreSQL database";
  
  source = {
    type = "database";
    location = "postgresql://localhost:5432/customers";
    credentials = {
      username = "db_user";
      password = "$DB_PASSWORD";  # Use environment variable
    };
    options = {
      type = "postgres";
      database = "customers";
      table = "customer_transactions";
      host = "db.example.com";
      port = 5432;
    };
  };
  
  destination = {
    dataset = "data/customers/transactions.csv";
    format = "csv";
    options = {
      delimiter = ",";
      header = true;
    };
  };
  
  transform = {
    type = "command";
    command = "awk -F, '{print $1,$2,$3,$4}' OFS=','";
  };
  
  schedule = {
    cron = "0 1 * * *";  # Every day at 1 AM
    timezone = "UTC";
  };
  
  dependencies = [];
}