{
  nixpkgs,
  root,
}: {
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    rule = inputs.${fragment}.${target};
    
    # Create a command to compile the rule
    compileRule = ''
      echo "Compiling rule: ${rule.name}"
      ${rule.compiler}/bin/compile-rule-${rule.name}
    '';
    
    # Create a command to apply the rule
    applyRule = ''
      if [ $# -lt 1 ]; then
        echo "Usage: apply INPUT_FILE [OUTPUT_FILE]"
        echo "Process INPUT_FILE using the ${rule.name} rule and write to OUTPUT_FILE"
        exit 1
      fi
      
      ${rule.processor}/bin/apply-rule-${rule.name} "$@"
    '';
    
    # Create a command to show rule documentation
    showDocs = ''
      echo "Rule documentation for: ${rule.name}"
      cat ${rule.docs}/share/doc/rule-${rule.name}.md
    '';
    
    # Create a command to view the rule content
    viewRule = ''
      echo "Viewing rule: ${rule.name}"
      cat ${rule.rule}/share/rules/${rule.name}.json | jq
    '';
    
    # Create a command to count rules
    countRules = ''
      echo "Counting rules in: ${rule.name}"
      jq length ${rule.rule}/share/rules/${rule.name}.json
    '';
    
    # Helper function to create a command
    mkCommand = system: {
      name,
      description,
      command,
    }: {
      inherit name description;
      package = pkgs.writeShellScriptBin name command;
      type = "app";
    };
    
  in [
    (mkCommand currentSystem {
      name = "compile";
      description = "Compile the rule";
      command = compileRule;
    })
    (mkCommand currentSystem {
      name = "apply";
      description = "Apply the rule to process a file";
      command = applyRule;
    })
    (mkCommand currentSystem {
      name = "docs";
      description = "Show rule documentation";
      command = showDocs;
    })
    (mkCommand currentSystem {
      name = "view";
      description = "View the rule content";
      command = viewRule;
    })
    (mkCommand currentSystem {
      name = "count";
      description = "Count rules in the rule set";
      command = countRules;
    })
  ];
}