{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "loadTests";
  type = "loadTest";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    loadTest = inputs.${fragment}.${target};
    
    # Create a command to run the load test
    runLoadTest = pkgs.writeShellScriptBin "load-test-${target}" ''
      echo "Running load test: ${loadTest.name}"
      
      # Create output directory
      mkdir -p ./load-test-results/${target}
      
      # Run the appropriate load testing tool
      case "${loadTest.tool}" in
        locust)
          ${pkgs.python3Packages.locust}/bin/locust \
            -f ${loadTest.script} \
            --headless \
            --users ${toString loadTest.users} \
            --spawn-rate ${toString loadTest.spawnRate} \
            --host ${loadTest.targetService} \
            --csv=./load-test-results/${target}/report
          ;;
        k6)
          ${pkgs.k6}/bin/k6 run \
            --out json=./load-test-results/${target}/report.json \
            ${loadTest.script}
          ;;
        *)
          echo "Unsupported load testing tool: ${loadTest.tool}"
          exit 1
          ;;
      esac
      
      echo "Load test complete. Results saved to ./load-test-results/${target}/"
    '';
    
  in [
    (mkCommand currentSystem {
      name = "load-test-${target}";
      description = "Run load test ${target} against ${loadTest.targetService}";
      package = runLoadTest;
    })
  ];
}