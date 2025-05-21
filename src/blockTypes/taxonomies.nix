{
  nixpkgs,
  root,
}: {
  currentSystem,
  fragment,
  target,
  inputs,
}: let
  pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
  l = nixpkgs.lib // builtins;
  taxonomy = inputs.${fragment}.${target};
  
  # Generate taxonomy visualization
  generateVisualization = ''
    mkdir -p $PRJ_ROOT/taxonomies
    cat > $PRJ_ROOT/taxonomies/${target}.dot << EOF
    digraph "${target}" {
      rankdir=TB;
      node [shape=box, style=filled, fillcolor=lightblue];
      ${let
        renderNode = prefix: node: name:
          if node ? children then
            l.concatStringsSep "\n  " ([
              "\"${prefix}\" -> \"${prefix}/${name}\" [label=\"${name}\"];"
            ] ++ l.mapAttrsToList (childName: childNode:
              renderNode "${prefix}/${name}" childNode childName
            ) node.children)
          else
            "\"${prefix}\" -> \"${prefix}/${name}\" [label=\"${name}\"];\n  \"${prefix}/${name}\" [fillcolor=lightgreen];";
      in
        l.concatStringsSep "\n  " (l.mapAttrsToList (name: node:
          renderNode target node name
        ) taxonomy.categories)}
    }
    EOF
    ${pkgs.graphviz}/bin/dot -Tsvg $PRJ_ROOT/taxonomies/${target}.dot -o $PRJ_ROOT/taxonomies/${target}.svg
    echo "Taxonomy visualization generated at taxonomies/${target}.svg"
  '';
  
  # Create a script to visualize the taxonomy
  visualizeTaxonomyScript = pkgs.writeShellScriptBin "visualize-taxonomy-${target}" ''
    ${generateVisualization}
  '';
  
in {
  # Return the visualization script
  visualize = visualizeTaxonomyScript;
}