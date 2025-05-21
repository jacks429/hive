{
  nixpkgs,
  root,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Extract all nodes from the lineage graph
  allNodes = config.nodes or {};
  
  # Extract all edges from the lineage graph
  allEdges = config.edges or {};
  
  # Compute the full impact analysis if not provided
  computedImpactAnalysis = 
    if config ? impactAnalysis then config.impactAnalysis
    else
      let
        # Build a reverse dependency map
        reverseDeps = l.foldl' (acc: source:
          l.foldl' (innerAcc: edge:
            innerAcc // {
              ${edge.target} = (innerAcc.${edge.target} or []) ++ [source];
            }
          ) acc (allEdges.${source} or [])
        ) {} (l.attrNames allEdges);
        
        # Recursive function to find all affected nodes
        findAffected = node: visited:
          if l.elem node visited then visited
          else
            let
              directDeps = allEdges.${node} or [];
              newVisited = visited ++ [node];
            in
              l.foldl' 
                (acc: dep: findAffected dep.target acc) 
                newVisited 
                directDeps;
        
        # Compute impact for each node
        impactMap = l.mapAttrs (node: _:
          l.filter (n: n != node) (findAffected node [])
        ) allNodes;
      in
        impactMap;
  
  # Generate documentation for the lineage
  documentation = ''
    # Data Lineage: ${config.name}
    
    ${config.description or ""}
    
    ## Data Sources
    
    ${l.concatMapStrings (name: let node = allNodes.${name}; in ''
      ### ${name}
      
      ${node.description or ""}
      
      - **Type**: ${node.type or "dataset"}
      - **Owner**: ${node.owner or "Unknown"}
      ${if node ? schema then "- **Schema**: ${l.toJSON node.schema}\n" else ""}
      ${if (node.tags or []) != [] then "- **Tags**: ${l.concatStringsSep ", " node.tags}\n" else ""}
      
    '') (l.attrNames allNodes)}
    
    ## Data Transformations
    
    ${l.concatMapStrings (source: 
      l.concatMapStrings (edge: ''
        ### ${source} → ${edge.target}
        
        ${edge.description or ""}
        
        - **Transformation**: ${edge.transformation}
        ${if edge ? pipeline then "- **Pipeline**: ${edge.pipeline}\n" else ""}
        ${if edge ? timestamp then "- **Last Run**: ${edge.timestamp}\n" else ""}
        
      '') (allEdges.${source} or [])
    ) (l.attrNames allEdges)}
    
    ## Impact Analysis
    
    ${l.concatMapStrings (node: ''
      - Changes to **${node}** affect: ${l.concatStringsSep ", " (computedImpactAnalysis.${node} or [])}
    '') (l.attrNames computedImpactAnalysis)}
  '';
  
  # Return the processed lineage with computed fields
  result = config // {
    impactAnalysis = computedImpactAnalysis;
    documentation = documentation;
  };
in
  result