{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;

  templates = {
    name = "templates";
    type = "templates";
    transform = import ../transformers/templatesConfigurations.nix;
    
    actions = {
      currentSystem,
      fragment,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
      template = inputs.${fragment}.${target};
      
      # Generate documentation
      generateDocs = ''
        cat > template-${target}.md << EOF
        # Template: ${template.name} (${template.type})
        
        ${template.description}
        
        ## Parameters
        
        ${l.concatMapStrings (paramName: let
          param = template.parameters.${paramName};
          defaultValue = if param ? default then " (default: \`${toString param.default}\`)" else "";
          required = if param ? required && param.required then " (required)" else "";
        in
          "- **${paramName}**${required}${defaultValue}: ${param.description or ""}\n"
        ) (l.attrNames template.parameters)}
        
        ## Usage
        
        To instantiate this template:
        
        \`\`\`bash
        # Basic usage
        nix run .#instantiate-${template.type}-${template.name} -- ${l.concatMapStrings (name: 
          let param = template.parameters.${name}; in
          if param.required or false then "--${name}=<value> " else ""
        ) (l.attrNames template.parameters)}
        
        # With all parameters
        nix run .#instantiate-${template.type}-${template.name} -- ${l.concatMapStrings (name: 
          "--${name}=<value> "
        ) (l.attrNames template.parameters)}
        \`\`\`
        
        EOF
      '';
      
      # Create a script to print template info
      infoScript = ''
        echo "Template: ${template.name} (${template.type})"
        echo "Description: ${template.description}"
        echo ""
        echo "Parameters:"
        ${l.concatMapStrings (paramName: let
          param = template.parameters.${paramName};
          defaultValue = if param ? default then " (default: ${toString param.default})" else "";
          required = if param ? required && param.required then " (required)" else "";
        in
          "echo \"  ${paramName}${required}${defaultValue}: ${param.description or ''}\"\n"
        ) (l.attrNames template.parameters)}
      '';
      
    in [
      (mkCommand currentSystem {
        name = "info";
        description = "Show template information";
        command = infoScript;
      })
      (mkCommand currentSystem {
        name = "docs";
        description = "Generate template documentation";
        command = generateDocs;
      })
      (mkCommand currentSystem {
        name = "instantiate";
        description = "Instantiate this template";
        command = ''
          ${template.instantiateFunction}/bin/instantiate-${template.type}-${template.name} "$@"
        '';
      })
    ];
  };
in
  templates