{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "regressionTests";
  type = "regressionTest";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    tests = inputs.${fragment}.${target};
    
    # Create a test runner
    runTests = pkgs.writeShellScriptBin "run-regression-tests-${target}" ''
      echo "Running regression tests for ${tests.name}"
      
      MODEL_ENDPOINT="${tests.modelEndpoint}"
      FAILURES=0
      TOTAL=0
      
      ${l.concatMapStrings (test: ''
        echo "Test case: ${test.id}"
        TOTAL=$((TOTAL + 1))
        
        # Call the model endpoint
        RESPONSE=$(curl -s -X POST "$MODEL_ENDPOINT" \
          -H "Content-Type: application/json" \
          -d '{"text": "${l.escapeShellArg test.input}"}')
        
        # Extract the output
        OUTPUT=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.output')
        
        # Compare with expected
        if [ "$OUTPUT" != "${l.escapeShellArg test.expected}" ]; then
          echo "❌ Test failed: Expected '${test.expected}', got '$OUTPUT'"
          FAILURES=$((FAILURES + 1))
        else
          echo "✅ Test passed"
        fi
      '') tests.testCases}
      
      echo "Tests completed: $((TOTAL - FAILURES))/$TOTAL passed"
      
      if [ "$FAILURES" -gt 0 ]; then
        echo "Regression test failed with $FAILURES failures"
        exit 1
      else
        echo "All regression tests passed"
        exit 0
      fi
    '';
    
    # Create a flake check
    check = pkgs.runCommand "regression-test-${target}" {} ''
      ${runTests}/bin/run-regression-tests-${target}
      touch $out
    '';
    
  in [
    (mkCommand currentSystem {
      name = "run-regression-tests-${target}";
      description = "Run regression tests for ${tests.name}";
      package = runTests;
    })
    {
      name = target;
      value = check;
    }
  ];
}