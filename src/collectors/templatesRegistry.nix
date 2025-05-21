{
  inputs,
  nixpkgs,
  root,
}: renamer: let
  l = nixpkgs.lib // builtins;
  
  # Get all template configurations
  templates = root.collectors.templatesConfigurations renamer;
  
  # Create a registry of template definitions, keyed by name
  templatesRegistry = l.mapAttrs (name: template: {
    inherit (template) name type description parameters template;
    validateParameters = template.validateParameters or null;
  }) templates;
  
  # Function to get a template by name
  getTemplate = name:
    if l.hasAttr name templatesRegistry
    then templatesRegistry.${name}
    else throw "Template not found: ${name}";
  
  # Function to get templates by type
  getTemplatesByType = type:
    l.filterAttrs (_: template: template.type == type) templatesRegistry;
  
  # Function to instantiate a pipeline from a template
  instantiatePipeline = templateName: params: let
    template = getTemplate templateName;
    
    # Validate that this is a pipeline template
    _ = if template.type != "pipeline"
        then throw "Template ${templateName} is not a pipeline template"
        else true;
    
    # Instantiate the template with parameters
    instantiated = root.collectors.templatesConfigurations.instantiateTemplate template params;
    
  in instantiated;
  
  # Function to instantiate a step from a template
  instantiateStep = templateName: params: let
    template = getTemplate templateName;
    
    # Validate that this is a step template
    _ = if template.type != "step"
        then throw "Template ${templateName} is not a step template"
        else true;
    
    # Instantiate the template with parameters
    instantiated = root.collectors.templatesConfigurations.instantiateTemplate template params;
    
  in instantiated;
  
  # Function to instantiate a workflow from a template
  instantiateWorkflow = templateName: params: let
    template = getTemplate templateName;
    
    # Validate that this is a workflow template
    _ = if template.type != "workflow"
        then throw "Template ${templateName} is not a workflow template"
        else true;
    
    # Instantiate the template with parameters
    instantiated = root.collectors.templatesConfigurations.instantiateTemplate template params;
    
  in instantiated;
  
  # Generate documentation for all templates
  allTemplatesDocs = let
    templatesList = l.mapAttrsToList (name: template: ''
      ## Template: ${template.name} (${template.type})
      
      ${template.description}
      
      ### Parameters
      
      ${l.concatMapStrings (paramName: let
        param = template.parameters.${paramName};
        defaultValue = if param ? default then " (default: `${toString param.default}`)" else "";
        required = if param ? required && param.required then " (required)" else "";
      in
        "- **${paramName}**${required}${defaultValue}: ${param.description or ""}\n"
      ) (l.attrNames template.parameters)}
      
      ---
    '') templatesRegistry;
  in ''
    # Templates Registry
    
    This document contains information about all available templates.
    
    ${l.concatStringsSep "\n" templatesList}
  '';
  
in {
  registry = templatesRegistry;
  documentation = allTemplatesDocs;
  
  # Helper functions
  getTemplate = getTemplate;
  getTemplatesByType = getTemplatesByType;
  instantiatePipeline = instantiatePipeline;
  instantiateStep = instantiateStep;
  instantiateWorkflow = instantiateWorkflow;
}