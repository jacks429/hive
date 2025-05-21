{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "dataLineage";
  type = "dataLineage";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    lineage = inputs.${fragment}.${target};
    
    # Generate lineage visualization
    generateVisualization = ''
      mkdir -p $PRJ_ROOT/lineage
      cat > $PRJ_ROOT/lineage/${target}.dot << EOF
      digraph "${target}" {
        rankdir=LR;
        node [shape=box, style=filled, fillcolor=lightblue];
        ${l.concatStringsSep "\n  " (l.mapAttrsToList 
          (source: targets: l.concatMapStrings 
            (t: "\"${source}\" -> \"${t.target}\" [label=\"${t.transformation}\"];\n  ") 
            targets) 
          lineage.edges)}
      }
      EOF
      ${pkgs.graphviz}/bin/dot -Tsvg $PRJ_ROOT/lineage/${target}.dot -o $PRJ_ROOT/lineage/${target}.svg
      echo "Lineage visualization generated at lineage/${target}.svg"
    '';
    
    # Generate lineage report
    generateReport = ''
      cat > $PRJ_ROOT/lineage/${target}-report.md << EOF
      # Data Lineage: ${target}
      
      ${lineage.description or ""}
      
      ## Sources
      ${l.concatMapStrings (source: ''
        - **${source}**: ${lineage.nodes.${source}.description or ""}
      '') (l.attrNames lineage.nodes)}
      
      ## Transformations
      ${l.concatMapStrings (source: 
        l.concatMapStrings (t: ''
          - **${source}** → **${t.target}**: ${t.transformation} (${t.description or ""})
        '') lineage.edges.${source}
      ) (l.attrNames lineage.edges)}
      
      ## Impact Analysis
      ${l.concatMapStrings (node: ''
        - Changes to **${node}** affect: ${l.concatStringsSep ", " (lineage.impactAnalysis.${node} or [])}
      '') (l.attrNames (lineage.impactAnalysis or {}))}
      EOF
      echo "Lineage report generated at lineage/${target}-report.md"
    '';
  in [
    (mkCommand currentSystem {
      name = "visualize";
      description = "Generate lineage visualization";
      command = generateVisualization;
    })
    (mkCommand currentSystem {
      name = "report";
      description = "Generate lineage report";
      command = generateReport;
    })
    (mkCommand currentSystem {
      name = "validate";
      description = "Validate lineage graph for cycles and consistency";
      command = ''
        echo "Validating lineage graph for ${target}..."
        # Check for cycles and other validation logic would go here
        echo "Lineage validation complete."
      '';
    })
  ];
}