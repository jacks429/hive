{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract rule configuration
  rule = config;
  
  # Process rules based on type
  processedRules = 
    if rule.type == "regex" then
      # For regex rules, ensure they're valid regex patterns
      map (r: {
        pattern = r.pattern or r;
        flags = r.flags or "";
        description = r.description or "";
        replacement = r.replacement or null;
      }) rule.rules
    else if rule.type == "normalization" then
      # For normalization rules, ensure they have pattern and replacement
      map (r: {
        pattern = r.pattern or r.from or "";
        replacement = r.replacement or r.to or "";
        description = r.description or "";
      }) rule.rules
    else if rule.type == "filtering" then
      # For filtering rules, ensure they have a condition
      map (r: {
        condition = r.condition or r;
        description = r.description or "";
      }) rule.rules
    else if rule.type == "tokenization" then
      # For tokenization rules, ensure they have a pattern
      map (r: {
        pattern = r.pattern or r;
        description = r.description or "";
      }) rule.rules
    else
      # Default to raw rules
      rule.rules;
  
  # Convert rules to JSON
  rulesJson = builtins.toJSON processedRules;
  
  # Create a derivation for the rules
  rulesDrv = pkgs.writeTextFile {
    name = "rule-${rule.name}";
    text = rulesJson;
    destination = "/share/rules/${rule.name}.json";
  };
  
  # Generate a script to compile the rules
  compileRuleScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Compiling rule: ${rule.name}"
    echo "Type: ${rule.type}"
    
    # Create output directory
    mkdir -p rules
    
    # Copy the rule file
    cp ${rulesDrv}/share/rules/${rule.name}.json rules/
    
    echo "Rule compiled to: rules/${rule.name}.json"
  '';
  
  # Create a derivation for the compilation script
  compileRuleScriptDrv = pkgs.writeScriptBin "compile-rule-${rule.name}" compileRuleScript;
  
  # Generate a script to apply the rules
  applyRuleScript = ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [ $# -lt 1 ]; then
      echo "Usage: apply-rule-${rule.name} INPUT_FILE [OUTPUT_FILE]"
      exit 1
    fi
    
    INPUT_FILE="$1"
    OUTPUT_FILE="''${2:-}"
    
    if [ -z "$OUTPUT_FILE" ]; then
      OUTPUT_FILE="''${INPUT_FILE%.*}.processed.''${INPUT_FILE##*.}"
    fi
    
    echo "Applying rule: ${rule.name}"
    echo "Input: $INPUT_FILE"
    echo "Output: $OUTPUT_FILE"
    
    # Ensure rule file is available
    mkdir -p rules
    cp ${rulesDrv}/share/rules/${rule.name}.json rules/
    
    # Apply the rule based on type
    case "${rule.type}" in
      "regex")
        # Apply regex patterns
        python3 -c "
import sys
import json
import re

# Load rules
with open('rules/${rule.name}.json', 'r') as f:
    rules = json.load(f)

# Read input file
with open('$INPUT_FILE', 'r') as f:
    text = f.read()

# Apply each regex rule
for rule in rules:
    pattern = rule['pattern']
    flags = rule['flags']
    replacement = rule['replacement']
    
    # Create regex object with appropriate flags
    regex_flags = 0
    if 'i' in flags:
        regex_flags |= re.IGNORECASE
    if 'm' in flags:
        regex_flags |= re.MULTILINE
    if 's' in flags:
        regex_flags |= re.DOTALL
        
    # Apply the regex
    if replacement is not None:
        text = re.sub(pattern, replacement, text, flags=regex_flags)
    else:
        # If no replacement, just find matches
        matches = re.finditer(pattern, text, flags=regex_flags)
        # Create a list of matches for output
        match_list = [{'match': m.group(0), 'start': m.start(), 'end': m.end()} for m in matches]
        # Write matches to output
        with open('$OUTPUT_FILE', 'w') as f:
            json.dump(match_list, f, indent=2)
        sys.exit(0)

# Write processed text to output
with open('$OUTPUT_FILE', 'w') as f:
    f.write(text)
        "
        ;;
      "normalization")
        # Apply normalization rules
        python3 -c "
import sys
import json

# Load rules
with open('rules/${rule.name}.json', 'r') as f:
    rules = json.load(f)

# Read input file
with open('$INPUT_FILE', 'r') as f:
    text = f.read()

# Apply each normalization rule
for rule in rules:
    pattern = rule['pattern']
    replacement = rule['replacement']
    text = text.replace(pattern, replacement)

# Write processed text to output
with open('$OUTPUT_FILE', 'w') as f:
    f.write(text)
        "
        ;;
      "filtering")
        # Apply filtering rules
        python3 -c "
import sys
import json
import re

# Load rules
with open('rules/${rule.name}.json', 'r') as f:
    rules = json.load(f)

# Read input file
with open('$INPUT_FILE', 'r') as f:
    lines = f.readlines()

# Apply each filtering rule
filtered_lines = []
for line in lines:
    keep_line = True
    for rule in rules:
        condition = rule['condition']
        # If line matches condition, filter it out
        if re.search(condition, line):
            keep_line = False
            break
    if keep_line:
        filtered_lines.append(line)

# Write filtered text to output
with open('$OUTPUT_FILE', 'w') as f:
    f.writelines(filtered_lines)
        "
        ;;
      "tokenization")
        # Apply tokenization rules
        python3 -c "
import sys
import json
import re

# Load rules
with open('rules/${rule.name}.json', 'r') as f:
    rules = json.load(f)

# Read input file
with open('$INPUT_FILE', 'r') as f:
    text = f.read()

# Combine all patterns into one regex
patterns = [rule['pattern'] for rule in rules]
combined_pattern = '|'.join(f'({pattern})' for pattern in patterns)

# Tokenize the text
tokens = re.findall(combined_pattern, text)

# Flatten the tokens (findall returns tuples for grouped patterns)
flat_tokens = []
for token_tuple in tokens:
    for token in token_tuple:
        if token:  # Only add non-empty matches
            flat_tokens.append(token)

# Write tokens to output
with open('$OUTPUT_FILE', 'w') as f:
    json.dump(flat_tokens, f, indent=2)
        "
        ;;
      *)
        # Generic rule processing
        echo "Rule type '${rule.type}' not supported for direct application."
        echo "Copying input to output."
        cp "$INPUT_FILE" "$OUTPUT_FILE"
        ;;
    esac
    
    echo "Rule application complete."
  '';
  
  # Create a derivation for the application script
  applyRuleScriptDrv = pkgs.writeScriptBin "apply-rule-${rule.name}" applyRuleScript;
  
  # Generate documentation
  documentation = ''
    # Rule: ${rule.name}
    
    ${rule.description}
    
    ## Type
    
    This is a **${rule.type}** rule.
    
    ## Applies To
    
    This rule applies to: **${rule.appliesTo}**
    
    ## Language
    
    Language: **${rule.language}**
    
    ## Rules
    
    ```json
    ${rulesJson}
    ```
    
    ## Processing Options
    
    - Case sensitive: ${if rule.caseSensitive then "Yes" else "No"}
    
    ## Usage
    
    ### Compile the rule
    
    ```bash
    nix run .#compile-rule-${rule.name}
    ```
    
    This will create the rule file at `rules/${rule.name}.json`.
    
    ### Apply the rule
    
    ```bash
    nix run .#apply-rule-${rule.name} -- input.txt output.txt
    ```
    
    This will process `input.txt` using the rule and write the result to `output.txt`.
    
    ### Reference in a pipeline
    
    To reference this rule in a pipeline, use:
    
    ```nix
    {
      inputs,
      cell,
    }: {
      name = "my-nlp-pipeline";
      steps = [
        {
          name = "process-with-rule";
          command = "nix run .#apply-rule-${rule.name} -- $INPUT_FILE $OUTPUT_FILE";
        }
      ];
    }
    ```
    
    Or access the rule file directly:
    
    ```nix
    {
      inputs,
      cell,
    }: {
      name = "my-nlp-pipeline";
      steps = [
        {
          name = "process-with-rule";
          command = "cat ${rulesDrv}/share/rules/${rule.name}.json | my-nlp-tool --rule-file=- $INPUT_FILE $OUTPUT_FILE";
        }
      ];
    }
    ```
  '';
  
  # Create a derivation for the documentation
  documentationDrv = pkgs.writeTextFile {
    name = "rule-${rule.name}-docs";
    text = documentation;
    destination = "/share/doc/rule-${rule.name}.md";
  };
  
  # Create a derivation that bundles everything together
  rulePackageDrv = pkgs.symlinkJoin {
    name = "rule-${rule.name}-package";
    paths = [
      rulesDrv
      compileRuleScriptDrv
      applyRuleScriptDrv
      documentationDrv
    ];
  };
  
in {
  # Original rule configuration
  inherit (rule) name description type language appliesTo;
  inherit (rule) format caseSensitive system;
  
  # Processed rules
  rules = processedRules;
  
  # Derivations
  rule = rulesDrv;
  compiler = compileRuleScriptDrv;
  processor = applyRuleScriptDrv;
  docs = documentationDrv;
  package = rulePackageDrv;
  
  # Metadata
  metadata = {
    type = "rule";
    ruleCount = builtins.length processedRules;
  };
}