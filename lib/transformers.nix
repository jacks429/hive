# SPDX-FileCopyrightText: 2023 The Hive Authors
#
# SPDX-License-Identifier: MIT

{ lib, pkgs }:

let
  l = lib // builtins;
in rec {
  #
  # Configuration handling
  #

  # Apply default values to a configuration
  withDefaults = config: defaults:
    defaults // (removeAttrs config ["__functor"]);

  # Validate a configuration against a schema
  validateConfig = config: schema:
    let
      # Check required fields
      requiredFields = l.filter (field: schema.${field}.required or false) (l.attrNames schema);
      missingFields = l.filter (field: !(l.hasAttr field config)) requiredFields;
      
      # Check field types
      typeErrors = l.mapAttrs (name: value:
        let
          expectedType = schema.${name}.type or null;
          actualType = l.typeOf value;
        in
          if expectedType == null then null
          else if expectedType != actualType then
            "Expected type '${expectedType}' but got '${actualType}'"
          else null
      ) config;
      
      # Filter out null errors
      actualTypeErrors = l.filterAttrs (name: value: value != null) typeErrors;
      
      # Build error message
      errorMsg = 
        if missingFields != [] then
          "Missing required fields: ${l.concatStringsSep ", " missingFields}"
        else if actualTypeErrors != {} then
          "Type errors: ${l.concatStringsSep ", " (l.mapAttrsToList (name: error: "${name}: ${error}") actualTypeErrors)}"
        else null;
    in
      if errorMsg != null then
        throw errorMsg
      else
        config;

  #
  # CLI argument parsing
  #

  # Generate a script with argument parsing
  withArgs = { name, description, args ? [], flags ? [] }: script:
    let
      # Generate help text
      helpText = ''
        ${description}
        
        Usage: ${name} ${l.concatMapStrings (arg: arg.required ? "<${arg.name}>" : "[${arg.name}]") args} ${l.concatMapStrings (flag: flag.type == "boolean" ? "[--${flag.name}]" : "[--${flag.name} <value>]") flags}
        
        Arguments:
        ${l.concatMapStrings (arg: "  ${arg.name}${arg.required ? "" : " (optional)"}: ${arg.description}\n") args}
        
        Options:
        ${l.concatMapStrings (flag: "  --${flag.name}: ${flag.description}\n") flags}
        
        Examples:
        ${l.concatStringsSep "\n" (l.map (example: "  ${example}") (l.splitString "\n" (l.removePrefix "\n" (l.removeSuffix "\n" (description.examples or "")))))}
      '';
      
      # Generate argument parsing code
      argParsingCode = ''
        # Show help if requested
        if [[ "$1" == "--help" || "$1" == "-h" ]]; then
          cat <<EOF
        ${helpText}
        EOF
          exit 0
        fi
        
        # Parse arguments
        ${l.concatMapStrings (arg: ''
        ${if arg.required then ''
        if [ $# -lt ${toString (l.elemAt args arg.position + 1)} ]; then
          echo "Error: Missing required argument '${arg.name}'"
          exit 1
        fi
        ${arg.name}="$${toString (arg.position + 1)}"
        '' else ''
        if [ $# -ge ${toString (arg.position + 1)} ]; then
          ${arg.name}="$${toString (arg.position + 1)}"
        else
          ${arg.name}="${arg.default or ""}"
        fi
        ''}
        '') args}
        
        # Parse flags
        ${l.concatMapStrings (flag: ''
        ${flag.name}="${flag.default or ""}"
        '') flags}
        
        while [[ $# -gt ${toString (l.length args)} ]]; do
          case "$${toString ((l.length args) + 1)}" in
            ${l.concatMapStrings (flag: ''
            --${flag.name})
              ${if flag.type == "boolean" then ''
              ${flag.name}="true"
              shift
              '' else ''
              if [ $# -lt ${toString ((l.length args) + 2)} ]; then
                echo "Error: Missing value for --${flag.name}"
                exit 1
              fi
              ${flag.name}="$${toString ((l.length args) + 2)}"
              shift 2
              ''}
              ;;
            '') flags}
            --help|-h)
              cat <<EOF
        ${helpText}
        EOF
              exit 0
              ;;
            *)
              echo "Error: Unknown option '$${toString ((l.length args) + 1)}'"
              exit 1
              ;;
          esac
        done
      '';
    in
      ''
        #!/usr/bin/env bash
        set -e
        
        ${argParsingCode}
        
        ${script}
      '';

  # Parse arguments from a script
  parseArgs = { args, flags ? [] }:
    let
      # Generate argument parsing code
      argParsingCode = ''
        # Parse arguments
        ${l.concatMapStrings (arg: ''
        ${if arg.required then ''
        if [ $# -lt ${toString (l.elemAt args arg.position + 1)} ]; then
          echo "Error: Missing required argument '${arg.name}'"
          exit 1
        fi
        ${arg.name}="$${toString (arg.position + 1)}"
        '' else ''
        if [ $# -ge ${toString (arg.position + 1)} ]; then
          ${arg.name}="$${toString (arg.position + 1)}"
        else
          ${arg.name}="${arg.default or ""}"
        fi
        ''}
        '') args}
        
        # Parse flags
        ${l.concatMapStrings (flag: ''
        ${flag.name}="${flag.default or ""}"
        '') flags}
        
        while [[ $# -gt ${toString (l.length args)} ]]; do
          case "$${toString ((l.length args) + 1)}" in
            ${l.concatMapStrings (flag: ''
            --${flag.name})
              ${if flag.type == "boolean" then ''
              ${flag.name}="true"
              shift
              '' else ''
              if [ $# -lt ${toString ((l.length args) + 2)} ]; then
                echo "Error: Missing value for --${flag.name}"
                exit 1
              fi
              ${flag.name}="$${toString ((l.length args) + 2)}"
              shift 2
              ''}
              ;;
            '') flags}
            *)
              echo "Error: Unknown option '$${toString ((l.length args) + 1)}'"
              exit 1
              ;;
          esac
        done
      '';
    in
      argParsingCode;

  #
  # Documentation generation
  #

  # Generate documentation for a transformer
  generateDocs = { name, description, usage, examples, params ? {} }:
    ''
      # ${name}
      
      ${description}
      
      ## Usage
      
      ${usage}
      
      ## Examples
      
      ${examples}
      
      ${if params != {} then ''
      ## Parameters
      
      ${formatParams params}
      '' else ""}
    '';

  # Format parameters for documentation
  formatParams = params:
    l.concatMapStrings (name:
      let param = params.${name}; in
      ''
      ### ${name}
      
      ${param.description or ""}
      
      ${if param ? type then "Type: `${param.type}`\n" else ""}
      ${if param ? default then "Default: `${l.toJSON param.default}`\n" else ""}
      ${if param ? required then "Required: ${if param.required then "Yes" else "No"}\n" else ""}
      
      ''
    ) (l.attrNames params);

  #
  # Derivation creation
  #

  # Create a script derivation
  mkScript = { name, description ? "", script }:
    pkgs.writeScriptBin name ''
      #!/usr/bin/env bash
      set -e
      
      ${if description != "" then ''
      # ${description}
      '' else ""}
      
      ${script}
    '';

  # Create a documentation derivation
  mkDocs = { name, content }:
    pkgs.writeTextFile {
      name = "${name}-docs";
      text = content;
      destination = "/share/doc/${name}.md";
    };

  # Create a package derivation that bundles multiple derivations
  mkPackage = { name, paths }:
    pkgs.symlinkJoin {
      inherit name paths;
    };

  #
  # Block discovery and enumeration
  #

  # Map a function over all blocks of a certain type
  mapBlocks = { cells, blockType, fn }:
    l.mapAttrs (cellName: cell:
      if l.hasAttr blockType cell
      then l.mapAttrs (blockName: block: fn { inherit cellName blockName block; }) cell.${blockType}
      else {}
    ) cells;

  # Filter blocks based on a predicate
  filterBlocks = { blocks, predicate }:
    l.filterAttrs (name: block: predicate block) blocks;

  #
  # Error handling
  #

  # Add error handling to a script
  withErrorHandling = script:
    ''
      # Error handling
      set -e
      trap 'echo "Error: Command failed with exit code $?"' ERR
      
      ${script}
    '';

  #
  # Result marshaling
  #

  # Convert a value to JSON
  toJSON = value:
    l.toJSON value;

  # Parse JSON into a value
  fromJSON = json:
    l.fromJSON json;

  #
  # Helpers for specific transformer types
  #

  # Create a model transformer
  mkModelTransformer = { name, description, modelUri, framework, params ? {}, service ? null }:
    let
      # Default service configuration
      defaultService = {
        enable = false;
        host = "0.0.0.0";
        port = 8000;
      };
      
      # Merge service configuration with defaults
      actualService = if service != null then defaultService // service else defaultService;
      
      # Create runner script
      runnerScript = withArgs {
        inherit name description;
        args = [
          { name = "input"; description = "Input file"; required = false; position = 0; }
          { name = "output"; description = "Output file"; required = false; position = 1; }
        ];
      } ''
        # Handle stdin/stdout if no files specified
        if [ -z "$input" ]; then
          input=$(mktemp)
          cat > "$input"
          REMOVE_INPUT=1
        fi
        
        if [ -z "$output" ]; then
          output=$(mktemp)
          REMOVE_OUTPUT=1
        fi
        
        # Create temporary config file
        CONFIG_FILE=$(mktemp)
        cat > "$CONFIG_FILE" << EOF
        {
          "model_uri": "${modelUri}",
          "framework": "${framework}",
          "params": ${toJSON params}
        }
        EOF
        
        # Run the model
        ${pkgs.python3}/bin/python ${pkgs.writeText "${name}-runner.py" ''
          import sys
          import json
          
          # Load configuration
          with open(sys.argv[1], 'r') as f:
              config = json.load(f)
          
          # Load input
          with open(sys.argv[2], 'r') as f:
              input_text = f.read()
          
          # Process input
          # ... model-specific processing ...
          
          # Write output
          with open(sys.argv[3], 'w') as f:
              f.write(json.dumps({"result": "processed"}))
        ''} "$CONFIG_FILE" "$input" "$output"
        
        # Output results
        if [ -n "$REMOVE_OUTPUT" ]; then
          cat "$output"
          rm "$output"
        fi
        
        # Clean up
        if [ -n "$REMOVE_INPUT" ]; then
          rm "$input"
        fi
        
        rm "$CONFIG_FILE"
      '';
      
      # Create service script if enabled
      serviceScript = if actualService.enable then
        withArgs {
          name = "serve-${name}";
          description = "Start ${name} as a service";
        } ''
          echo "Starting ${name} service"
          echo "Listening on ${actualService.host}:${toString actualService.port}"
          
          # Create temporary config file
          CONFIG_FILE=$(mktemp)
          cat > "$CONFIG_FILE" << EOF
          {
            "model_uri": "${modelUri}",
            "framework": "${framework}",
            "params": ${toJSON params},
            "service": {
              "host": "${actualService.host}",
              "port": ${toString actualService.port}
            }
          }
          EOF
          
          # Run the service
          ${pkgs.python3}/bin/python ${pkgs.writeText "${name}-service.py" ''
            import sys
            import json
            from http.server import HTTPServer, BaseHTTPRequestHandler
            
            # Load configuration
            with open(sys.argv[1], 'r') as f:
                config = json.load(f)
            
            class ModelHandler(BaseHTTPRequestHandler):
                def do_POST(self):
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    request = json.loads(post_data.decode('utf-8'))
                    
                    # Process request
                    # ... model-specific processing ...
                    
                    # Send response
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({"result": "processed"}).encode('utf-8'))
            
            # Start server
            server = HTTPServer((config['service']['host'], config['service']['port']), ModelHandler)
            print(f"Server started at http://{config['service']['host']}:{config['service']['port']}")
            server.serve_forever()
          ''} "$CONFIG_FILE"
          
          # Clean up
          rm "$CONFIG_FILE"
        ''
      else null;
      
      # Generate documentation
      docs = generateDocs {
        inherit name description;
        usage = ''
          ```bash
          # Process text from stdin
          echo "Text to process" | ${name}
          
          # Process text from file
          ${name} input.txt output.txt
          ```
          
          ${if actualService.enable then ''
          To start as a service:
          
          ```bash
          serve-${name}
          ```
          
          Then use the API:
          
          ```bash
          curl -X POST http://${actualService.host}:${toString actualService.port}/process \
            -H "Content-Type: application/json" \
            -d '{"text": "Text to process"}'
          ```
          '' else ""}
        '';
        examples = ''
          ```bash
          echo "Example input" | ${name}
          ```
        '';
        params = {
          modelUri = {
            description = "URI of the model to use";
            type = "string";
            required = true;
          };
          framework = {
            description = "Framework used by the model";
            type = "string";
            required = true;
          };
        };
      };
      
      # Create derivations
      runnerDrv = mkScript {
        name = "${name}";
        inherit description;
        script = runnerScript;
      };
      
      serviceDrv = if actualService.enable then
        mkScript {
          name = "serve-${name}";
          description = "Start ${name} as a service";
          script = serviceScript;
        }
      else null;
      
      docsDrv = mkDocs {
        inherit name;
        content = docs;
      };
      
      # Bundle derivations
      packageDrv = mkPackage {
        inherit name;
        paths = if actualService.enable
          then [ runnerDrv serviceDrv docsDrv ]
          else [ runnerDrv docsDrv ];
      };
    in {
      # Original configuration
      inherit name description modelUri framework params;
      service = actualService;
      
      # Derivations
      runner = runnerDrv;
      service = serviceDrv;
      docs = docsDrv;
      package = packageDrv;
    };
}
