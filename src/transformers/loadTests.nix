{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract load test definition
  loadTest = {
    inherit (config) name description;
    target = config.target or {};
    scenarios = config.scenarios or [];
    duration = config.duration or 60;
    users = config.users or 10;
    ramp-up = config.ramp-up or 30;
  };
  
  # Generate JSON configuration file
  configJson = pkgs.writeTextFile {
    name = "${loadTest.name}-config.json";
    text = builtins.toJSON {
      name = loadTest.name;
      description = loadTest.description;
      target = loadTest.target;
      scenarios = loadTest.scenarios;
      duration = loadTest.duration;
      users = loadTest.users;
      ramp-up = loadTest.ramp-up;
    };
  };
  
  # Generate k6 script for load testing
  k6Script = pkgs.writeTextFile {
    name = "${loadTest.name}-k6.js";
    text = ''
      import http from 'k6/http';
      import { check, sleep } from 'k6';
      
      // Load test configuration
      const config = JSON.parse(open('${configJson}'));
      
      // Test options
      export const options = {
        vus: config.users,
        duration: config.duration + 's',
        thresholds: {
          http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
        },
      };
      
      // Initialize scenario functions
      const scenarios = {
        ${l.concatMapStrings (scenario: ''
        ${scenario.name}: function() {
          const url = '${loadTest.target.base-url}${scenario.endpoint}';
          const params = {
            headers: ${builtins.toJSON (scenario.headers or {})},
          };
          
          const response = http.${scenario.method or "get"}(url, ${
            if scenario.method == "post" || scenario.method == "put" 
            then "JSON.stringify(" + builtins.toJSON (scenario.body or {}) + "), params" 
            else "params"
          });
          
          check(response, {
            'status is ${toString (scenario.expected-status or 200)}': (r) => r.status === ${toString (scenario.expected-status or 200)},
            ${l.concatMapStrings (check: ''
            '${check.description}': (r) => ${check.condition},
            '') (scenario.checks or [])}
          });
          
          sleep(${toString (scenario.delay or 1)});
        },
        '') loadTest.scenarios}
      };
      
      // Main function
      export default function() {
        // Randomly select a scenario to run
        const scenarioNames = Object.keys(scenarios);
        const randomScenario = scenarioNames[Math.floor(Math.random() * scenarioNames.length)];
        
        // Run the selected scenario
        scenarios[randomScenario]();
      }
    '';
  };
  
  # Generate markdown documentation
  docsMd = pkgs.writeTextFile {
    name = "${loadTest.name}-docs.md";
    text = ''
      # Load Test: ${loadTest.name}
      
      ${loadTest.description}
      
      ## Target
      
      - **Base URL**: ${loadTest.target.base-url or ""}
      - **Environment**: ${loadTest.target.environment or "production"}
      
      ## Test Configuration
      
      - **Duration**: ${toString loadTest.duration} seconds
      - **Virtual Users**: ${toString loadTest.users}
      - **Ramp-up Period**: ${toString loadTest.ramp-up} seconds
      
      ## Scenarios
      
      ${l.concatMapStrings (scenario: ''
      ### ${scenario.name}
      
      - **Endpoint**: ${scenario.endpoint}
      - **Method**: ${scenario.method or "GET"}
      - **Expected Status**: ${toString (scenario.expected-status or 200)}
      ${if scenario.body != null then ''
      - **Request Body**:
      ```json
      ${builtins.toJSON scenario.body}
      ```
      '' else ""}
      
      #### Checks
      
      ${l.concatMapStrings (check: ''
      - ${check.description}
      '') (scenario.checks or [])}
      
      '') loadTest.scenarios}
    '';
  };
  
  # Create a command to run the load test
  runScript = pkgs.writeShellScriptBin "run-load-test-${loadTest.name}" ''
    #!/usr/bin/env bash
    
    echo "Running load test: ${loadTest.name}"
    echo "Target: ${loadTest.target.base-url or ""}"
    echo "Duration: ${toString loadTest.duration} seconds"
    echo "Virtual Users: ${toString loadTest.users}"
    echo ""
    
    # Check if k6 is installed
    if ! command -v k6 &> /dev/null; then
      echo "Error: k6 is not installed. Please install it first:"
      echo "  nix-shell -p k6"
      exit 1
    fi
    
    # Create a temporary directory for the test
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy the test files
    cp ${configJson} $TEMP_DIR/config.json
    cp ${k6Script} $TEMP_DIR/script.js
    
    # Run the test
    cd $TEMP_DIR
    k6 run script.js "$@"
    
    echo ""
    echo "Load test completed."
  '';
  
in {
  # Original load test configuration
  inherit (loadTest) name description;
  inherit (loadTest) target scenarios duration users;
  
  # Derivations
  config = configJson;
  script = k6Script;
  documentation = docsMd;
  run = runScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
