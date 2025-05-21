{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "leaderboards";
  type = "leaderboard";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    leaderboard = inputs.${fragment}.${target};
    
    # Get all tracking runs for this task
    trackingRuns = l.filter 
      (run: run.task == leaderboard.task) 
      (l.attrValues inputs.trackingRuns);
    
    # Sort runs by primary metric
    sortedRuns = l.sort 
      (a: b: 
        if leaderboard.sort == "desc" 
        then a.scores.${leaderboard.primaryMetric} > b.scores.${leaderboard.primaryMetric}
        else a.scores.${leaderboard.primaryMetric} < b.scores.${leaderboard.primaryMetric}
      ) 
      trackingRuns;
    
    # Generate markdown leaderboard
    generateMarkdown = pkgs.writeTextFile {
      name = "${target}-leaderboard.md";
      text = ''
        # ${leaderboard.name} Leaderboard
        
        Task: ${leaderboard.task}
        
        | Model | ${l.concatMapStrings (metric: metric + " | ") leaderboard.metrics} Date | Commit |
        |-------|${l.concatMapStrings (_: "-------|") leaderboard.metrics} ------|--------|
        ${l.concatMapStrings (run: ''
        | ${run.model} | ${l.concatMapStrings (metric: toString (run.scores.${metric} or "N/A") + " | ") leaderboard.metrics} ${run.timestamp or "N/A"} | ${run.sha or "N/A"} |
        '') sortedRuns}
      '';
    };
    
    # Generate CSV leaderboard
    generateCsv = pkgs.writeTextFile {
      name = "${target}-leaderboard.csv";
      text = ''
        Model,${l.concatStringsSep "," leaderboard.metrics},Date,Commit
        ${l.concatMapStrings (run: ''
        ${run.model},${l.concatMapStrings (metric: toString (run.scores.${metric} or "") + ",") leaderboard.metrics}${run.timestamp or ""},${run.sha or ""}
        '') sortedRuns}
      '';
    };
    
    # Create a command to generate the leaderboard
    generateLeaderboard = pkgs.writeShellScriptBin "generate-leaderboard-${target}" ''
      echo "Generating leaderboard for ${leaderboard.name}"
      
      # Create output directory
      mkdir -p ./leaderboards
      
      # Copy markdown and CSV files
      cp ${generateMarkdown} ./leaderboards/${target}.md
      cp ${generateCsv} ./leaderboards/${target}.csv
      
      echo "Leaderboard generated at:"
      echo "  - ./leaderboards/${target}.md"
      echo "  - ./leaderboards/${target}.csv"
    '';
    
  in [
    (mkCommand currentSystem {
      name = "generate-leaderboard-${target}";
      description = "Generate leaderboard for ${leaderboard.name}";
      package = generateLeaderboard;
    })
  ];
}