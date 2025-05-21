{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "baselineResults";
  type = "baselineResult";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    baseline = inputs.${fragment}.${target};
    
    # Generate JSON output
    baselineJson = pkgs.writeTextFile {
      name = "${target}-baseline.json";
      text = builtins.toJSON {
        inherit (baseline) name task model version dataset metrics;
        timestamp = baseline.timestamp or (builtins.substring 0 10 (builtins.currentTime));
      };
    };
    
    # Create a command to check against the baseline
    checkBaseline = pkgs.writeShellScriptBin "check-baseline-${target}" ''
      if [ $# -lt 1 ]; then
        echo "Usage: check-baseline-${target} RESULTS_JSON"
        echo "Compare current results against baseline ${baseline.name}"
        exit 1
      fi
      
      RESULTS_FILE="$1"
      BASELINE_FILE="${baselineJson}"
      
      echo "Comparing results against baseline: ${baseline.name}"
      echo "Baseline metrics:"
      ${pkgs.jq}/bin/jq '.metrics' "$BASELINE_FILE"
      
      echo "Current metrics:"
      ${pkgs.jq}/bin/jq '.metrics' "$RESULTS_FILE"
      
      # Compare each metric
      FAILURES=0
      ${l.concatStringsSep "\n" (l.mapAttrsToList (metric: value: ''
        CURRENT_VALUE=$(${pkgs.jq}/bin/jq -r '.metrics.${metric} // "N/A"' "$RESULTS_FILE")
        BASELINE_VALUE="${toString value}"
        
        if [ "$CURRENT_VALUE" = "N/A" ]; then
          echo "❌ Metric ${metric} missing in current results"
          FAILURES=$((FAILURES + 1))
        elif (( $(echo "$CURRENT_VALUE < $BASELINE_VALUE" | ${pkgs.bc}/bin/bc -l) )); then
          echo "❌ Metric ${metric} regression: $CURRENT_VALUE < $BASELINE_VALUE"
          FAILURES=$((FAILURES + 1))
        else
          echo "✅ Metric ${metric}: $CURRENT_VALUE >= $BASELINE_VALUE"
        fi
      '') baseline.metrics)}
      
      if [ "$FAILURES" -gt 0 ]; then
        echo "Failed baseline comparison with $FAILURES metrics below baseline"
        exit 1
      else
        echo "All metrics meet or exceed baseline values"
      fi
    '';
    
  in [
    (mkCommand currentSystem {
      name = "check-baseline-${target}";
      description = "Check results against baseline ${baseline.name}";
      package = checkBaseline;
    })
  ];
}