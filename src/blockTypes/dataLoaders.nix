{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "dataLoaders";
  type = "dataLoader";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    dataLoader = inputs.${fragment}.${target};
    
    # Generate documentation
    generateDocs = ''
      mkdir -p $PRJ_ROOT/docs/data-loaders
      cat > $PRJ_ROOT/docs/data-loaders/${target}.md << EOF
      ${dataLoader.documentation}
      EOF
      echo "Documentation generated at docs/data-loaders/${target}.md"
    '';
    
    # Generate loader script
    generateLoaderScript = ''
      mkdir -p $PRJ_ROOT/scripts/data-loaders
      cat > $PRJ_ROOT/scripts/data-loaders/${target}.sh << EOF
      ${dataLoader.loaderScript}
      EOF
      chmod +x $PRJ_ROOT/scripts/data-loaders/${target}.sh
      echo "Loader script generated at scripts/data-loaders/${target}.sh"
    '';
    
    # Generate schedule configuration if applicable
    generateSchedule = 
      if dataLoader ? schedule && dataLoader.schedule != null then ''
        mkdir -p $PRJ_ROOT/schedules/data-loaders
        cat > $PRJ_ROOT/schedules/data-loaders/${target}.cron << EOF
        # ${dataLoader.name}: ${dataLoader.description}
        ${dataLoader.schedule.cron} $PRJ_ROOT/scripts/data-loaders/${target}.sh
        EOF
        echo "Schedule configuration generated at schedules/data-loaders/${target}.cron"
      '' else ''
        echo "No schedule configuration generated (no schedule defined)"
      '';
    
    # Run the loader
    runLoader = ''
      $PRJ_ROOT/scripts/data-loaders/${target}.sh
    '';
    
  in [
    (mkCommand currentSystem {
      name = "docs";
      description = "Generate documentation for the data loader";
      command = generateDocs;
    })
    (mkCommand currentSystem {
      name = "script";
      description = "Generate loader script";
      command = generateLoaderScript;
    })
    (mkCommand currentSystem {
      name = "schedule";
      description = "Generate schedule configuration";
      command = generateSchedule;
    })
    (mkCommand currentSystem {
      name = "generate";
      description = "Generate all data loader files";
      command = ''
        ${generateDocs}
        ${generateLoaderScript}
        ${generateSchedule}
        
        echo "Data loader ${dataLoader.name} generated successfully"
      '';
    })
    (mkCommand currentSystem {
      name = "run";
      description = "Run the data loader";
      command = runLoader;
    })
  ];
}