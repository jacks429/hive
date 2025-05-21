{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract all jobs from the schedule
  allJobs = config.jobs or [];
  
  # Generate crontab entries
  crontabEntries = l.concatMapStrings (job: ''
    # ${job.name}: ${job.description or ""}
    ${job.cronExpression} ${job.user or "root"} ${job.command}
  '') allJobs;
  
  # Generate systemd timer units
  systemdTimerUnits = l.listToAttrs (l.map (job: {
    name = job.name;
    value = {
      description = job.description or "";
      command = job.command;
      user = job.user or "root";
      timer = {
        onCalendar = job.cronExpression;
        persistent = job.persistent or false;
        randomizedDelaySec = job.randomDelay or 0;
      };
    };
  }) allJobs);
  
  # Generate GitHub Actions workflow
  githubActionsWorkflow = ''
    name: ${config.name}
    
    on:
      schedule:
    ${l.concatMapStrings (job: ''
        # ${job.name}: ${job.description or ""}
        - cron: '${job.cronExpression}'
    '') allJobs}
    
    jobs:
    ${l.concatMapStrings (job: ''
      ${job.name}:
        name: ${job.name}
        runs-on: ${job.runsOn or "ubuntu-latest"}
        steps:
          - name: Checkout code
            uses: actions/checkout@v3
          
          - name: Set up Nix
            uses: cachix/install-nix-action@v20
          
          - name: Run job
            run: ${job.command}
    '') allJobs}
  '';
  
  # Generate documentation
  documentation = ''
    # Schedule: ${config.name}
    
    ${config.description or ""}
    
    ## Jobs
    
    ${l.concatMapStrings (job: ''
      ### ${job.name}
      
      ${job.description or ""}
      
      - **Command**: \`${job.command}\`
      - **Schedule**: ${job.cronExpression}
      ${if job ? user then "- **User**: ${job.user}\n" else ""}
      ${if (job.tags or []) != [] then "- **Tags**: ${l.concatStringsSep ", " job.tags}\n" else ""}
      ${if job ? dependencies then "- **Dependencies**: ${l.concatStringsSep ", " job.dependencies}\n" else ""}
      
    '') allJobs}
    
    ## Crontab Format
    
    ```
    ${crontabEntries}
    ```
    
    ## GitHub Actions Workflow
    
    ```yaml
    ${githubActionsWorkflow}
    ```
  '';
  
  # Return the processed schedule with generated outputs
  result = config // {
    crontabEntries = crontabEntries;
    systemdTimerUnits = systemdTimerUnits;
    githubActionsWorkflow = githubActionsWorkflow;
    documentation = documentation;
  };
in
  result
