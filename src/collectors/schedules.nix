{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  cellBlock = "schedules";
  l = nixpkgs.lib // builtins;
  inherit (root.lib) collectors;

  # Define the schema for schedules
  schema = {
    name = {
      description = "Name of the schedule";
      type = "string";
      required = true;
    };
    description = {
      description = "Description of the schedule";
      type = "string";
      required = false;
    };
    jobs = {
      description = "List of scheduled jobs";
      type = "list";
      required = false;
    };
    system = {
      description = "System for which this schedule is defined";
      type = "string";
      required = true;
    };
  };

  # Process schedule configuration
  processConfig = config: let
    # Apply basic metadata processing
    metadata = collectors.processMetadata config;

    # Process with defaults
    withDefaults = {
      # Jobs
      jobs = config.jobs or [];
    };
  in
    # Combine processed parts and validate
    collectors.validateConfig
      (metadata // withDefaults // {
        system = config.system;
      })
      schema;

  # Create the collector using the library function
  walk = collectors.mkCollector {
    inherit cellBlock processConfig;
  } renamer;

  # Create a registry of schedules
  createRegistry = schedules: let
    # Create the basic registry
    registry = collectors.mkRegistry {
      collector = schedules;
      keyFn = name: item: item.name;
    };

    # Generate a calendar view of all jobs
    calendarView = let
      allJobs = l.flatten (l.map (schedule:
        l.map (job: {
          inherit (job) name frequency;
          schedule = schedule.name;
          description = job.description or "";
        }) schedule.jobs
      ) (l.attrValues registry));

      # Group jobs by frequency
      jobsByFrequency = l.groupBy (job: job.frequency) allJobs;
    in
      l.mapAttrs (frequency: jobs:
        l.map (job: {
          inherit (job) name schedule description;
        }) jobs
      ) jobsByFrequency;

    # Generate documentation for the registry
    registryDocs = ''
      # Schedules Registry

      This registry contains ${toString (l.length (l.attrNames registry))} schedules with a total of
      ${toString (l.length (l.flatten (l.map (s: s.jobs) (l.attrValues registry))))} jobs.

      ## Schedules

      ${l.concatMapStrings (name: let schedule = registry.${name}; in ''
        ### ${name}

        ${schedule.description}

        #### Jobs:

        ${l.concatMapStrings (job: ''
          - **${job.name}**: ${job.description or ""} (${job.frequency})
        '') schedule.jobs}

      '') (l.attrNames registry)}

      ## Calendar View

      ${l.concatMapStrings (frequency: ''
        ### ${frequency}

        ${l.concatMapStrings (job: ''
          - **${job.name}** (${job.schedule}): ${job.description}
        '') calendarView.${frequency}}

      '') (l.attrNames calendarView)}
    '';
  in {
    schedules = registry;
    calendar = calendarView;
    documentation = registryDocs;
  };
in {
  # Return the basic collector
  collector = walk;

  # Return a function to create a registry
  registry = createRegistry;
}
