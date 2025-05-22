{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Create Grafana dashboard configuration file
  dashboardsYaml = pkgs.writeTextFile {
    name = "dashboards.yml";
    text = ''
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: 'Dashboards'
        type: file
        disableDeletion: false
        updateIntervalSeconds: 10
        options:
          path: /grafana/dashboards
    '';
  };
  
  # Create monitoring wrapper script
  monitoringScript = pkgs.writeShellScriptBin "monitoring-wrapper-${config.name}" ''
    #!/usr/bin/env bash
    set -e
    
    # Create configuration directory
    CONFIG_DIR="$PRJ_ROOT/monitoring/${config.name}"
    mkdir -p "$CONFIG_DIR"
    
    # Create Grafana dashboard config
    mkdir -p $CONFIG_DIR/grafana/provisioning/dashboards
    cp ${dashboardsYaml} $CONFIG_DIR/grafana/provisioning/dashboards/dashboards.yml
    
    # Create Prometheus configuration
    cat > $CONFIG_DIR/prometheus.yml << EOF
    global:
      scrape_interval: ${config.scrapeInterval or "15s"}
      evaluation_interval: ${config.evaluationInterval or "15s"}
    
    scrape_configs:
      - job_name: '${config.name}'
        static_configs:
          - targets: [${l.concatStringsSep ", " (map (target: "'${target}'") (config.targets or ["localhost:8000"]))}]
    
    ${config.prometheusExtraConfig or ""}
    EOF
    
    # Create alert rules if specified
    ${if config.alertRules != null then ''
      cat > $CONFIG_DIR/alert_rules.yml << EOF
      groups:
      - name: ${config.name}_alerts
        rules:
        ${l.concatMapStrings (rule: "  - alert: ${rule.name}\n    expr: ${rule.expr}\n    for: ${rule.for or "5m"}\n    labels:\n      severity: ${rule.severity or "warning"}\n    annotations:\n      summary: ${rule.summary}\n      description: ${rule.description or ""}\n") config.alertRules}
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
        ${config.alertManagerConfig or "# No alert manager config provided"}
      EOF
    '' else ""}
    
    # Start Prometheus
    echo "Starting Prometheus..."
    prometheus --config.file=$CONFIG_DIR/prometheus.yml --storage.tsdb.path=/tmp/prometheus-${config.name} &
    PROMETHEUS_PID=$!
    
    # Start Alert Manager if alert rules are specified
    ${if config.alertRules != null then ''
      echo "Starting Alert Manager..."
      alertmanager --config.file=$CONFIG_DIR/alertmanager.yml --storage.path=/tmp/alertmanager-${config.name} &
      ALERTMANAGER_PID=$!
    '' else ""}
    
    # Start Grafana if dashboards are specified
    ${if config.dashboards != null then ''
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
      
      # Create Grafana dashboard directory
      mkdir -p $CONFIG_DIR/grafana/dashboards
      
      # Copy dashboard files
      ${l.concatMapStrings (dashboard: "cp ${dashboard} $CONFIG_DIR/grafana/dashboards/\n") config.dashboards}
      
      # Start Grafana
      grafana-server --config=$CONFIG_DIR/grafana/grafana.ini --homepath=${pkgs.grafana}/share/grafana --pidfile=/tmp/grafana-${config.name}.pid &
      GRAFANA_PID=$!
      
      echo "Grafana available at http://localhost:3000"
    '' else ""}
    
    echo "Monitoring system started. Press Ctrl+C to stop."
    
    # Handle termination
    function cleanup {
      echo "Stopping monitoring system..."
      kill $PROMETHEUS_PID
      ${if config.alertRules != null then "kill $ALERTMANAGER_PID" else ""}
      ${if config.dashboards != null then "kill $GRAFANA_PID" else ""}
    }
    
    trap cleanup EXIT
    
    # Wait for user to press Ctrl+C
    wait
  '';
  
in {
  # Return the original configuration
  inherit (config) name description;
  
  # Return the generated script
  script = monitoringScript;
}
