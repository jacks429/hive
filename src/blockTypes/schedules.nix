{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "schedules";
  type = "schedule";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    schedule = inputs.${fragment}.${target};
    
    # Generate documentation
    generateDocs = ''
      mkdir -p $PRJ_ROOT/docs/schedules
      cat > $PRJ_ROOT/docs/schedules/${target}.md << EOF
      ${schedule.documentation}
      EOF
      echo "Documentation generated at docs/schedules/${target}.md"
    '';
    
    # Generate crontab file
    generateCrontab = ''
      mkdir -p $PRJ_ROOT/schedules
      cat > $PRJ_ROOT/schedules/${target}.crontab << EOF
      ${schedule.crontabEntries}
      EOF
      echo "Crontab file generated at schedules/${target}.crontab"
    '';
    
    # Generate systemd timer units
    generateSystemdTimers = ''
      mkdir -p $PRJ_ROOT/schedules/systemd
      
      ${l.concatMapStrings (name: let unit = schedule.systemdTimerUnits.${name}; in ''
        # Generate service unit
        cat > $PRJ_ROOT/schedules/systemd/${target}-${name}.service << EOF
        [Unit]
        Description=${unit.description}
        
        [Service]
        Type=oneshot
        User=${unit.user}
        ExecStart=${unit.command}
        
        [Install]
        WantedBy=multi-user.target
        EOF
        
        # Generate timer unit
        cat > $PRJ_ROOT/schedules/systemd/${target}-${name}.timer << EOF
        [Unit]
        Description=Timer for ${unit.description}
        
        [Timer]
        OnCalendar=${unit.timer.onCalendar}
        Persistent=${if unit.timer.persistent then "true" else "false"}
        RandomizedDelaySec=${toString unit.timer.randomizedDelaySec}
        
        [Install]
        WantedBy=timers.target
        EOF
      '') (l.attrNames schedule.systemdTimerUnits)}
      
      echo "Systemd timer units generated at schedules/systemd/"
    '';
    
    # Generate GitHub Actions workflow
    generateGithubActions = ''
      mkdir -p $PRJ_ROOT/.github/workflows
      cat > $PRJ_ROOT/.github/workflows/${target}.yml << EOF
      ${schedule.githubActionsWorkflow}
      EOF
      echo "GitHub Actions workflow generated at .github/workflows/${target}.yml"
    '';
    
  in [
    (mkCommand currentSystem {
      name = "docs";
      description = "Generate documentation for the schedule";
      command = generateDocs;
    })
    (mkCommand currentSystem {
      name = "crontab";
      description = "Generate crontab file";
      command = generateCrontab;
    })
    (mkCommand currentSystem {
      name = "systemd";
      description = "Generate systemd timer units";
      command = generateSystemdTimers;
    })
    (mkCommand currentSystem {
      name = "github";
      description = "Generate GitHub Actions workflow";
      command = generateGithubActions;
    })
    (mkCommand currentSystem {
      name = "generate";
      description = "Generate all schedule files";
      command = ''
        ${generateDocs}
        ${generateCrontab}
        ${generateSystemdTimers}
        ${generateGithubActions}
        
        echo "Schedule ${schedule.name} generated successfully"
      '';
    })
  ];
}
