{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract leaderboard definition
  leaderboard = {
    inherit (config) name description task;
    inherit (config) primaryMetric metrics sort;
    displayOptions = config.displayOptions or {};
  };
  
  # Generate markdown leaderboard
  generateMarkdown = pkgs.writeTextFile {
    name = "${leaderboard.name}-leaderboard.md";
    text = ''
      # ${leaderboard.name} Leaderboard
      
      Task: ${leaderboard.task}
      
      | Model | ${l.concatMapStrings (metric: metric + " | ") leaderboard.metrics} Date | Commit |
      |-------|${l.concatMapStrings (_: "-------|") leaderboard.metrics} ------|--------|
      
      *No entries yet*
    '';
  };
  
  # Generate CSV leaderboard
  generateCsv = pkgs.writeTextFile {
    name = "${leaderboard.name}-leaderboard.csv";
    text = ''
      Model,${l.concatStringsSep "," leaderboard.metrics},Date,Commit
    '';
  };
  
  # Create a command to generate the leaderboard
  generateLeaderboardScript = pkgs.writeShellScriptBin "generate-leaderboard-${leaderboard.name}" ''
    echo "Generating leaderboard for ${leaderboard.name}"
    
    # Create output directory
    mkdir -p ./leaderboards
    
    # Copy markdown and CSV files
    cp ${generateMarkdown} ./leaderboards/${leaderboard.name}.md
    cp ${generateCsv} ./leaderboards/${leaderboard.name}.csv
    
    echo "Leaderboard generated at:"
    echo "  - ./leaderboards/${leaderboard.name}.md"
    echo "  - ./leaderboards/${leaderboard.name}.csv"
  '';
  
  # Create a command to add an entry to the leaderboard
  addEntryScript = pkgs.writeShellScriptBin "add-leaderboard-entry-${leaderboard.name}" ''
    #!/usr/bin/env bash
    
    if [ $# -lt 2 ]; then
      echo "Usage: add-leaderboard-entry-${leaderboard.name} MODEL_NAME METRIC_VALUES..."
      echo "Example: add-leaderboard-entry-${leaderboard.name} 'My Model' 0.95 0.87 0.92"
      exit 1
    fi
    
    MODEL_NAME="$1"
    shift
    
    # Check if we have the right number of metrics
    if [ $# -ne ${toString (l.length leaderboard.metrics)} ]; then
      echo "Error: Expected ${toString (l.length leaderboard.metrics)} metrics (${l.concatStringsSep ", " leaderboard.metrics}), got $# values"
      exit 1
    fi
    
    # Get current date
    DATE=$(date +"%Y-%m-%d")
    
    # Get current git commit if in a git repo
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")
    
    # Create leaderboards directory if it doesn't exist
    mkdir -p ./leaderboards
    
    # Create files if they don't exist
    if [ ! -f ./leaderboards/${leaderboard.name}.md ]; then
      cp ${generateMarkdown} ./leaderboards/${leaderboard.name}.md
    fi
    
    if [ ! -f ./leaderboards/${leaderboard.name}.csv ]; then
      cp ${generateCsv} ./leaderboards/${leaderboard.name}.csv
    fi
    
    # Add entry to CSV
    echo "$MODEL_NAME,$(echo "$@" | tr ' ' ','),$DATE,$COMMIT" >> ./leaderboards/${leaderboard.name}.csv
    
    # Update markdown file
    if grep -q "No entries yet" ./leaderboards/${leaderboard.name}.md; then
      # Remove "No entries yet" line
      sed -i '/\*No entries yet\*/d' ./leaderboards/${leaderboard.name}.md
    fi
    
    # Add entry to markdown
    METRICS_STR=""
    for metric in "$@"; do
      METRICS_STR="$METRICS_STR$metric | "
    done
    
    echo "| $MODEL_NAME | $METRICS_STR$DATE | $COMMIT |" >> ./leaderboards/${leaderboard.name}.md
    
    echo "Added entry to leaderboard:"
    echo "  - Model: $MODEL_NAME"
    echo "  - Metrics: $@"
    echo "  - Date: $DATE"
    echo "  - Commit: $COMMIT"
  '';
  
in {
  # Original leaderboard configuration
  inherit (leaderboard) name description task;
  inherit (leaderboard) primaryMetric metrics sort;
  
  # Derivations
  markdown = generateMarkdown;
  csv = generateCsv;
  generateLeaderboard = generateLeaderboardScript;
  addEntry = addEntryScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
