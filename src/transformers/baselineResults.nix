{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract baseline result definition
  baseline = {
    inherit (config) name description task;
    inherit (config) metrics results;
    timestamp = config.timestamp or "";
    commit = config.commit or "";
  };
  
  # Generate JSON result file
  resultJson = pkgs.writeTextFile {
    name = "${baseline.name}-result.json";
    text = builtins.toJSON {
      name = baseline.name;
      task = baseline.task;
      metrics = baseline.metrics;
      results = baseline.results;
      timestamp = baseline.timestamp;
      commit = baseline.commit;
    };
  };
  
  # Generate markdown report
  reportMd = pkgs.writeTextFile {
    name = "${baseline.name}-report.md";
    text = ''
      # Baseline Result: ${baseline.name}
      
      ${baseline.description}
      
      ## Task
      
      ${baseline.task}
      
      ## Results
      
      | Metric | Value |
      |--------|-------|
      ${l.concatMapStrings (metric: ''
      | ${metric} | ${toString (baseline.results.${metric} or "N/A")} |
      '') baseline.metrics}
      
      ## Metadata
      
      - Timestamp: ${baseline.timestamp}
      - Commit: ${baseline.commit}
    '';
  };
  
  # Create a command to compare with other results
  compareScript = pkgs.writeShellScriptBin "compare-baseline-${baseline.name}" ''
    #!/usr/bin/env bash
    
    if [ $# -lt 1 ]; then
      echo "Usage: compare-baseline-${baseline.name} RESULT_JSON_FILE"
      exit 1
    fi
    
    RESULT_FILE="$1"
    BASELINE_FILE="${resultJson}"
    
    echo "Comparing results with baseline: ${baseline.name}"
    echo ""
    
    # Use jq to compare results
    ${pkgs.jq}/bin/jq -n --argfile baseline "$BASELINE_FILE" --argfile result "$RESULT_FILE" '
    {
      "baseline": $baseline.name,
      "compared_to": $result.name,
      "task": $baseline.task,
      "metrics": [
        $baseline.metrics[] | . as $metric | {
          "metric": $metric,
          "baseline_value": $baseline.results[$metric],
          "result_value": $result.results[$metric],
          "difference": ($result.results[$metric] - $baseline.results[$metric]),
          "percent_change": (($result.results[$metric] - $baseline.results[$metric]) / $baseline.results[$metric] * 100)
        }
      ]
    }' | ${pkgs.jq}/bin/jq '.'
  '';
  
in {
  # Original baseline configuration
  inherit (baseline) name description task;
  inherit (baseline) metrics results timestamp commit;
  
  # Derivations
  json = resultJson;
  report = reportMd;
  compare = compareScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
