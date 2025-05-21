{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract source configuration
  source = config.source or {};
  sourceType = source.type or "file";
  sourceLocation = source.location or "";
  sourceCredentials = source.credentials or null;
  sourceOptions = source.options or {};
  
  # Extract destination configuration
  destination = config.destination or {};
  destinationDataset = destination.dataset or "";
  destinationFormat = destination.format or "raw";
  destinationOptions = destination.options or {};
  
  # Generate source-specific load commands
  sourceCommands = 
    if sourceType == "file" then ''
      echo "Loading from file: ${sourceLocation}"
      cp ${sourceLocation} $TEMP_DIR/data
    ''
    else if sourceType == "s3" then ''
      echo "Loading from S3: ${sourceLocation}"
      aws s3 cp ${sourceLocation} $TEMP_DIR/data ${l.concatStringsSep " " (l.mapAttrsToList (k: v: "--${k} ${v}") sourceOptions)}
    ''
    else if sourceType == "http" then ''
      echo "Loading from HTTP: ${sourceLocation}"
      curl -o $TEMP_DIR/data ${l.concatStringsSep " " (l.mapAttrsToList (k: v: "--${k} ${v}") sourceOptions)} "${sourceLocation}"
    ''
    else if sourceType == "database" then ''
      echo "Loading from database: ${sourceLocation}"
      ${if sourceOptions.type or "" == "postgres" then ''
        PGPASSWORD=${sourceCredentials.password} pg_dump -h ${sourceOptions.host or "localhost"} -p ${toString (sourceOptions.port or 5432)} -U ${sourceCredentials.username} -d ${sourceOptions.database} -t ${sourceOptions.table or ""} -f $TEMP_DIR/data
      '' else if sourceOptions.type or "" == "mysql" then ''
        mysqldump -h ${sourceOptions.host or "localhost"} -P ${toString (sourceOptions.port or 3306)} -u ${sourceCredentials.username} -p${sourceCredentials.password} ${sourceOptions.database} ${sourceOptions.table or ""} > $TEMP_DIR/data
      '' else ''
        echo "Unsupported database type: ${sourceOptions.type or ""}"
        exit 1
      ''}
    ''
    else if sourceType == "api" then ''
      echo "Loading from API: ${sourceLocation}"
      curl -o $TEMP_DIR/data ${l.concatStringsSep " " (l.mapAttrsToList (k: v: "--${k} ${v}") sourceOptions)} "${sourceLocation}"
    ''
    else ''
      echo "Unsupported source type: ${sourceType}"
      exit 1
    '';
  
  # Generate transformation command if transform is specified
  transformCommand = 
    if config.transform == null then ''
      echo "No transformation specified, using raw data"
      cp $TEMP_DIR/data $TEMP_DIR/transformed
    ''
    else if config.transform.type or "" == "jq" then ''
      echo "Applying jq transformation"
      cat $TEMP_DIR/data | jq '${config.transform.query}' > $TEMP_DIR/transformed
    ''
    else if config.transform.type or "" == "script" then ''
      echo "Applying script transformation"
      ${config.transform.script} $TEMP_DIR/data $TEMP_DIR/transformed
    ''
    else if config.transform.type or "" == "command" then ''
      echo "Applying command transformation"
      ${config.transform.command} < $TEMP_DIR/data > $TEMP_DIR/transformed
    ''
    else ''
      echo "Unsupported transformation type: ${config.transform.type or ""}"
      exit 1
    '';
  
  # Generate destination-specific store commands
  destinationCommands = ''
    echo "Storing data to dataset: ${destinationDataset}"
    mkdir -p $(dirname ${destinationDataset})
    cp $TEMP_DIR/transformed ${destinationDataset}
    echo "Data loaded successfully to ${destinationDataset}"
  '';
  
  # Generate the complete loader script
  loaderScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Starting data loader: ${config.name}"
    echo "${config.description}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    # Load data from source
    ${sourceCommands}
    
    # Apply transformation
    ${transformCommand}
    
    # Store data to destination
    ${destinationCommands}
    
    echo "Data loader ${config.name} completed successfully"
  '';
  
  # Generate documentation
  documentation = ''
    # Data Loader: ${config.name}
    
    ${config.description}
    
    ## Source
    
    - **Type**: ${sourceType}
    - **Location**: ${sourceLocation}
    ${if sourceOptions != {} then "- **Options**: " + builtins.toJSON sourceOptions else ""}
    
    ## Destination
    
    - **Dataset**: ${destinationDataset}
    - **Format**: ${destinationFormat}
    ${if destinationOptions != {} then "- **Options**: " + builtins.toJSON destinationOptions else ""}
    
    ## Transformation
    
    ${if config.transform == null then "No transformation applied." else ''
    - **Type**: ${config.transform.type}
    ${if config.transform.type == "jq" then "- **Query**: `" + config.transform.query + "`" else ""}
    ${if config.transform.type == "script" then "- **Script**: `" + config.transform.script + "`" else ""}
    ${if config.transform.type == "command" then "- **Command**: `" + config.transform.command + "`" else ""}
    ''}
    
    ## Schedule
    
    ${if config.schedule == null then "No schedule defined." else ''
    - **Cron**: ${config.schedule.cron}
    ${if config.schedule ? timezone then "- **Timezone**: ${config.schedule.timezone}" else ""}
    ''}
    
    ## Dependencies
    
    ${if config.dependencies == [] then "No dependencies." else l.concatMapStrings (dep: ''
    - ${dep}
    '') config.dependencies}
  '';
  
  # Return the processed data loader with generated outputs
  result = config // {
    loaderScript = loaderScript;
    documentation = documentation;
  };
in
  result