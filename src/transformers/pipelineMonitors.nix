{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Apply defaults to configuration
  monitor = transformers.withDefaults config {
    metrics = [];
    alerts = [];
    schedule = { interval = "1h"; };
  };
  
  # Generate monitor script
  monitorScript = transformers.withArgs {
    name = "run-pipeline-monitor-${monitor.name}";
    description = "Run pipeline monitor: ${monitor.name}";
    args = [
      { name = "PIPELINE_PATH"; description = "Path to the pipeline configuration"; required = true; position = 0; }
      { name = "OUTPUT_PATH"; description = "Path to save the monitoring results"; required = false; position = 1; }
    ];
  } ''
    echo "Running pipeline monitor: ${monitor.name}"
    echo "Pipeline: $PIPELINE_PATH"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./pipeline-monitor-${monitor.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${monitor.name}",
      "pipeline": ${transformers.toJSON monitor.pipeline},
      "metrics": ${transformers.toJSON monitor.metrics},
      "alerts": ${transformers.toJSON monitor.alerts},
      "schedule": ${transformers.toJSON monitor.schedule}
    }
    EOF
    
    # Run the pipeline monitor
    ${pkgs.python3.withPackages (ps: with ps; [ 
      pyyaml requests
    ])}/bin/python ${root.utils.pipelineMonitor or "${pkgs.writeText "pipeline_monitor.py" ''
      import json
      import sys
      import os
      import time
      import random
      from datetime import datetime
      
      def main():
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load pipeline configuration
          pipeline_path = sys.argv[2]
          print(f"Loading pipeline configuration from {pipeline_path}")
          with open(pipeline_path, 'r') as f:
              pipeline_config = json.load(f)
          
          # Set output path
          output_path = sys.argv[3]
          
          # Run monitoring
          print(f"Monitoring pipeline: {pipeline_config.get('name', 'unknown')}")
          print(f"Metrics: {config['metrics']}")
          
          # Create results structure
          results = {
              "monitor": config['name'],
              "pipeline": pipeline_config.get('name', 'unknown'),
              "timestamp": datetime.now().isoformat(),
              "metrics": {},
              "alerts": []
          }
          
          # Collect metrics
          for metric in config['metrics']:
              print(f"Collecting metric: {metric}")
              
              # Simulate metric collection (for demonstration)
              if metric == 'latency':
                  value = random.uniform(50, 500)  # ms
                  threshold = 200  # ms
                  alert = value > threshold
              elif metric == 'error_rate':
                  value = random.uniform(0, 0.1)  # 0-10%
                  threshold = 0.05  # 5%
                  alert = value > threshold
              elif metric == 'throughput':
                  value = random.uniform(10, 100)  # requests/sec
                  threshold = 20  # requests/sec
                  alert = value < threshold
              else:
                  value = random.uniform(0, 1)
                  threshold = 0.5
                  alert = False
              
              results["metrics"][metric] = {
                  "value": value,
                  "threshold": threshold,
                  "alert": alert
              }
              
              if alert:
                  alert_config = next((a for a in config['alerts'] if a.get('metric') == metric), None)
                  if alert_config:
                      results["alerts"].append({
                          "metric": metric,
                          "value": value,
                          "threshold": threshold,
                          "message": alert_config.get('message', f"{metric} threshold exceeded"),
                          "severity": alert_config.get('severity', 'warning')
                      })
          
          # Save results
          print(f"Saving results to {output_path}")
          results_file = os.path.join(output_path, f"results_{int(time.time())}.json")
          with open(results_file, 'w') as f:
              json.dump(results, f, indent=2)
          
          # Generate report
          report_file = os.path.join(output_path, 'latest_report.md')
          with open(report_file, 'w') as f:
              f.write(f"# Pipeline Monitoring Report: {config['name']}\n\n")
              f.write(f"Pipeline: {pipeline_config.get('name', 'unknown')}\n\n")
              f.write(f"Timestamp: {results['timestamp']}\n\n")
              
              f.write("## Metrics\n\n")
              f.write("| Metric | Value | Threshold | Status |\n")
              f.write("|--------|-------|-----------|--------|\n")
              
              for metric, data in results["metrics"].items():
                  status = "❌ Alert" if data["alert"] else "✅ OK"
                  f.write(f"| {metric} | {data['value']:.4f} | {data['threshold']:.4f} | {status} |\n")
              
              if results["alerts"]:
                  f.write("\n## Alerts\n\n")
                  for alert in results["alerts"]:
                      f.write(f"### {alert['metric']} ({alert['severity']})\n\n")
                      f.write(f"{alert['message']}\n\n")
                      f.write(f"- Value: {alert['value']:.4f}\n")
                      f.write(f"- Threshold: {alert['threshold']:.4f}\n\n")
          
          print(f"Monitoring report saved to {report_file}")
          
          # Exit with error if alerts were triggered
          if results["alerts"]:
              print(f"Alerts triggered: {len(results['alerts'])}")
              sys.exit(1)
          else:
              print("No alerts triggered")
      
      if __name__ == "__main__":
          main()
    ''}"} "$CONFIG_FILE" "$PIPELINE_PATH" "$OUTPUT_PATH"
    
    # Store exit code
    EXIT_CODE=$?
    
    # Clean up
    rm "$CONFIG_FILE"
    
    if [ $EXIT_CODE -eq 0 ]; then
      echo "Pipeline monitoring completed. No alerts triggered."
    else
      echo "Pipeline monitoring completed. Alerts were triggered!"
    fi
    
    echo "Results saved to $OUTPUT_PATH"
    echo "Latest report: $OUTPUT_PATH/latest_report.md"
    
    exit $EXIT_CODE
  '';
  
  # Generate service script
  serviceScript = transformers.withArgs {
    name = "start-pipeline-monitor-service-${monitor.name}";
    description = "Start pipeline monitor service: ${monitor.name}";
    args = [
      { name = "PIPELINE_PATH"; description = "Path to the pipeline configuration"; required = true; position = 0; }
      { name = "OUTPUT_PATH"; description = "Path to save the monitoring results"; required = false; position = 1; }
    ];
  } ''
    echo "Starting pipeline monitor service: ${monitor.name}"
    echo "Pipeline: $PIPELINE_PATH"
    
    # Create output directory if not specified
    if [ -z "$OUTPUT_PATH" ]; then
      OUTPUT_PATH="./pipeline-monitor-${monitor.name}"
      mkdir -p "$OUTPUT_PATH"
    fi
    
    echo "Output will be saved to: $OUTPUT_PATH"
    
    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    cat > "$CONFIG_FILE" << EOF
    {
      "name": "${monitor.name}",
      "pipeline": ${transformers.toJSON monitor.pipeline},
      "metrics": ${transformers.toJSON monitor.metrics},
      "alerts": ${transformers.toJSON monitor.alerts},
      "schedule": ${transformers.toJSON monitor.schedule}
    }
    EOF
    
    # Parse interval to seconds
    INTERVAL="${monitor.schedule.interval}"
    SECONDS=3600  # Default: 1 hour
    
    if [[ $INTERVAL =~ ([0-9]+)s ]]; then
      SECONDS=''${BASH_REMATCH[1]}
    elif [[ $INTERVAL =~ ([0-9]+)m ]]; then
      SECONDS=$((''${BASH_REMATCH[1]} * 60))
    elif [[ $INTERVAL =~ ([0-9]+)h ]]; then
      SECONDS=$((''${BASH_REMATCH[1]} * 3600))
    elif [[ $INTERVAL =~ ([0-9]+)d ]]; then
      SECONDS=$((''${BASH_REMATCH[1]} * 86400))
    fi
    
    echo "Monitoring interval: $INTERVAL ($SECONDS seconds)"
    
    # Start monitoring loop
    echo "Press Ctrl+C to stop monitoring"
    
    while true; do
      echo "Running monitor at $(date)"
      
      # Run the monitor
      run-pipeline-monitor-${monitor.name} "$PIPELINE_PATH" "$OUTPUT_PATH"
      
      echo "Waiting $SECONDS seconds until next check..."
      sleep $SECONDS
    done
  '';
  
  # Generate documentation
  monitorDocs = transformers.generateDocs {
    name = "Pipeline Monitor: ${monitor.name}";
    description = monitor.description;
    usage = ''
      ```bash
      # Run the pipeline monitor once
      run-pipeline-monitor-${monitor.name} /path/to/pipeline.json /path/to/output
      
      # Start the pipeline monitor service
      start-pipeline-monitor-service-${monitor.name} /path/to/pipeline.json /path/to/output
      ```
    '';
    examples = ''
      ```bash
      # Example: Monitor a pipeline once
      run-pipeline-monitor-${monitor.name} ./pipelines/inference.json ./monitoring
      
      # Example: Start a continuous monitoring service
      start-pipeline-monitor-service-${monitor.name} ./pipelines/inference.json ./monitoring
      ```
    '';
    params = {
      pipeline = {
        description = "Pipeline configuration";
        type = "attrset";
        value = monitor.pipeline;
      };
      metrics = {
        description = "Metrics to monitor";
        type = "list";
        value = monitor.metrics;
      };
      alerts = {
        description = "Alert configurations";
        type = "list";
        value = monitor.alerts;
      };
      schedule = {
        description = "Monitoring schedule";
        type = "attrset";
        value = monitor.schedule;
      };
    };
  };
  
  # Create derivations
  monitorDrv = transformers.mkScript {
    name = "run-pipeline-monitor-${monitor.name}";
    description = "Run pipeline monitor: ${monitor.name}";
    script = monitorScript;
  };
  
  serviceDrv = transformers.mkScript {
    name = "start-pipeline-monitor-service-${monitor.name}";
    description = "Start pipeline monitor service: ${monitor.name}";
    script = serviceScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${monitor.name}-pipeline-monitor";
    content = monitorDocs;
  };
  
in {
  # Original monitor configuration
  inherit (monitor) name description pipeline metrics alerts schedule;
  
  # Derivations
  run = monitorDrv;
  service = serviceDrv;
  docs = docsDrv;
  
  # Add metadata
  metadata = monitor.metadata or {};
}
