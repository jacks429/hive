{
  nixpkgs,
  root,
}: monitor: let
  l = nixpkgs.lib // builtins;
  pkgs = nixpkgs.legacyPackages.${monitor.system};
  
  # Create a script to start the monitoring system
  startScript = ''
    #!/usr/bin/env bash
    set -e
    
    echo "Starting monitoring for: ${monitor.name}"
    
    # Create configuration directory
    CONFIG_DIR=$(mktemp -d)
    trap "rm -rf $CONFIG_DIR" EXIT
    
    # Create Prometheus configuration
    cat > $CONFIG_DIR/prometheus.yml << EOF
    global:
      scrape_interval: ${monitor.scrapeInterval or "15s"}
      evaluation_interval: ${monitor.evaluationInterval or "15s"}
    
    scrape_configs:
      - job_name: '${monitor.name}'
        static_configs:
          - targets: [${l.concatStringsSep ", " (map (target: "'${target}'") (monitor.targets or ["localhost:8000"]))}]
    
    ${monitor.prometheusExtraConfig or ""}
    EOF
    
    # Create alert rules if specified
    ${if monitor.alertRules != null then ''
      cat > $CONFIG_DIR/alert_rules.yml << EOF
      groups:
      - name: ${monitor.name}_alerts
        rules:
        ${l.concatMapStrings (rule: "  - alert: ${rule.name}\n    expr: ${rule.expr}\n    for: ${rule.for or "5m"}\n    labels:\n      severity: ${rule.severity or "warning"}\n    annotations:\n      summary: ${rule.summary}\n      description: ${rule.description or ""}\n") monitor.alertRules}
      EOF
      
      # Add alert manager to Prometheus config
      cat >> $CONFIG_DIR/prometheus.yml << EOF
      alerting:
        alertmanagers:
        - static_configs:
          - targets: ['localhost:9093']
      
      rule_files:
        - "alert_rules.yml"
      EOF
      
      # Create alert manager config
      cat > $CONFIG_DIR/alertmanager.yml << EOF
      route:
        group_by: ['alertname']
        group_wait: 30s
        group_interval: 5m
        repeat_interval: 1h
        receiver: 'default'
      
      receivers:
      - name: 'default'
        ${monitor.alertManagerConfig or "# No alert manager config provided"}
      EOF
    '' else ""}
    
    # Start Prometheus
    echo "Starting Prometheus..."
    prometheus --config.file=$CONFIG_DIR/prometheus.yml --storage.tsdb.path=/tmp/prometheus-${monitor.name} &
    PROMETHEUS_PID=$!
    
    # Start Alert Manager if alert rules are specified
    ${if monitor.alertRules != null then ''
      echo "Starting Alert Manager..."
      alertmanager --config.file=$CONFIG_DIR/alertmanager.yml --storage.path=/tmp/alertmanager-${monitor.name} &
      ALERTMANAGER_PID=$!
    '' else ""}
    
    # Start Grafana if dashboards are specified
    ${if monitor.dashboards != null then ''
      echo "Starting Grafana..."
      # Create Grafana datasource config
      mkdir -p $CONFIG_DIR/grafana/provisioning/datasources
      cat > $CONFIG_DIR/grafana/provisioning/datasources/prometheus.yml << EOF
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://localhost:9090
        isDefault: true
      EOF
      
      # Create Grafana dashboard config
      mkdir -p $CONFIG_DIR/grafana/provisioning/dashboards
      cat > $CONFIG_DIR/grafana/provisioning/dashboards/dashboards.yml << EOF
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        updateIntervalSeconds: 10
        options:
          path: $CONFIG_DIR/grafana/dashboards
      EOF
      
      # Create dashboard files
      mkdir -p $CONFIG_DIR/grafana/dashboards
      ${l.concatMapStrings (dashboard: "cp ${dashboard} $CONFIG_DIR/grafana/dashboards/\n") monitor.dashboards}
      
      # Start Grafana
      grafana-server --config=$CONFIG_DIR/grafana/grafana.ini --homepath=${pkgs.grafana}/share/grafana --pidfile=/tmp/grafana-${monitor.name}.pid &
      GRAFANA_PID=$!
      
      echo "Grafana available at http://localhost:3000"
    '' else ""}
    
    echo "Monitoring system started. Press Ctrl+C to stop."
    
    # Handle termination
    function cleanup {
      echo "Stopping monitoring system..."
      kill $PROMETHEUS_PID
      ${if monitor.alertRules != null then "kill $ALERTMANAGER_PID" else ""}
      ${if monitor.dashboards != null then "kill $GRAFANA_PID" else ""}
    }
    
    trap cleanup EXIT
    
    # Wait for user to press Ctrl+C
    wait
  '';
  
  # Create start script derivation
  startDrv = pkgs.writeScriptBin "monitor-pipeline-${monitor.name}" startScript;
  
in startDrv