{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "thresholdPolicies";
  type = "thresholdPolicy";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    policy = inputs.${fragment}.${target};
    
    # Generate JSON output
    policyJson = pkgs.writeTextFile {
      name = "${target}-policy.json";
      text = builtins.toJSON {
        inherit (policy) name task thresholds;
        slices = policy.slices or {};
      };
    };
    
    # Create a command to evaluate against thresholds
    evalThresholds = pkgs.writeShellScriptBin "eval-threshold-${target}" ''
      if [ $# -lt 1 ]; then
        echo "Usage: eval-threshold-${target} RESULTS_JSON [SLICE]"
        echo "Evaluate results against threshold policy ${policy.name}"
        echo "Optional: Specify a slice name to use slice-specific thresholds"
        exit 1
      fi
      
      RESULTS_FILE="$1"
      SLICE="$2"
      POLICY_FILE="${policyJson}"
      
      echo "Evaluating results against policy: ${policy.name}"
      
      # Determine which thresholds to use
      if [ -n "$SLICE" ] && ${pkgs.jq}/bin/jq -e ".slices[\"$SLICE\"]" "$POLICY_FILE" > /dev/null; then
        echo "Using slice-specific thresholds for: $SLICE"
        THRESHOLDS=$(${pkgs.jq}/bin/jq -c ".slices[\"$SLICE\"]" "$POLICY_FILE")
      else
        if [ -n "$SLICE" ]; then
          echo "No slice-specific thresholds for: $SLICE, using default thresholds"
        else
          echo "Using default thresholds"
        fi
        THRESHOLDS=$(${pkgs.jq}/bin/jq -c ".thresholds" "$POLICY_FILE")
      fi
      
      # Evaluate each threshold
      FAILURES=0
      WARNINGS=0
      
      for threshold in $(echo "$THRESHOLDS" | ${pkgs.jq}/bin/jq -c '.[]'); do
        METRIC=$(echo "$threshold" | ${pkgs.jq}/bin/jq -r '.metric')
        ACTION=$(echo "$threshold" | ${pkgs.jq}/bin/jq -r '.action')
        MESSAGE=$(echo "$threshold" | ${pkgs.jq}/bin/jq -r '.message // ""')
        
        CURRENT_VALUE=$(${pkgs.jq}/bin/jq -r ".metrics.$METRIC // \"N/A\"" "$RESULTS_FILE")
        
        if [ "$CURRENT_VALUE" = "N/A" ]; then
          echo "❌ Metric $METRIC missing in results"
          if [ "$ACTION" = "fail" ]; then
            FAILURES=$((FAILURES + 1))
          elif [ "$ACTION" = "warn" ]; then
            WARNINGS=$((WARNINGS + 1))
          fi
          continue
        fi
        
        # Check min threshold if present
        MIN_THRESHOLD=$(echo "$threshold" | ${pkgs.jq}/bin/jq -r '.min // "N/A"')
        if [ "$MIN_THRESHOLD" != "N/A" ] && (( $(echo "$CURRENT_VALUE < $MIN_THRESHOLD" | ${pkgs.bc}/bin/bc -l) )); then
          echo "❌ Metric $METRIC below minimum: $CURRENT_VALUE < $MIN_THRESHOLD"
          if [ -n "$MESSAGE" ]; then echo "   $MESSAGE"; fi
          if [ "$ACTION" = "fail" ]; then
            FAILURES=$((FAILURES + 1))
          elif [ "$ACTION" = "warn" ]; then
            WARNINGS=$((WARNINGS + 1))
          fi
          continue
        fi
        
        # Check max threshold if present
        MAX_THRESHOLD=$(echo "$threshold" | ${pkgs.jq}/bin/jq -r '.max // "N/A"')
        if [ "$MAX_THRESHOLD" != "N/A" ] && (( $(echo "$CURRENT_VALUE > $MAX_THRESHOLD" | ${pkgs.bc}/bin/bc -l) )); then
          echo "❌ Metric $METRIC above maximum: $CURRENT_VALUE > $MAX_THRESHOLD"
          if [ -n "$MESSAGE" ]; then echo "   $MESSAGE"; fi
          if [ "$ACTION" = "fail" ]; then
            FAILURES=$((FAILURES + 1))
          elif [ "$ACTION" = "warn" ]; then
            WARNINGS=$((WARNINGS + 1))
          fi
          continue
        fi
        
        echo "✅ Metric $METRIC: $CURRENT_VALUE passes thresholds"
      done
      
      if [ "$FAILURES" -gt 0 ]; then
        echo "Failed threshold evaluation with $FAILURES failures and $WARNINGS warnings"
        exit 1
      elif [ "$WARNINGS" -gt 0 ]; then
        echo "Passed threshold evaluation with $WARNINGS warnings"
        exit 0
      else
        echo "All metrics pass thresholds"
        exit 0
      fi
    '';
    
  in [
    (mkCommand currentSystem {
      name = "eval-threshold-${target}";
      description = "Evaluate results against threshold policy ${policy.name}";
      package = evalThresholds;
    })
  ];
}