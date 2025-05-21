{
  nixpkgs,
  root,
  inputs,
}: let
  l = nixpkgs.lib // builtins;
  
  # Get all taxonomies from the collector
  taxonomies = root.collectors.taxonomies (cell: target: "${cell}-${target}");
  
  # Create lookup functions
  lookupCategory = taxonomyName: path: let
    taxonomy = taxonomies.${taxonomyName};
    pathParts = l.splitString "/" path;
    
    # Recursive function to navigate the category tree
    findInTree = tree: parts:
      if parts == [] then tree
      else if tree ? children && tree.children ? ${l.head parts} then
        findInTree tree.children.${l.head parts} (l.tail parts)
      else null;
    
    # Start at the root and navigate down
    result = l.foldl' (acc: part:
      if acc == null then null
      else if acc ? children && acc.children ? ${part} then acc.children.${part}
      else null
    ) taxonomy.categories pathParts;
  in
    result;
  
  # Function to list all categories in a taxonomy
  listCategories = taxonomyName: let
    taxonomy = taxonomies.${taxonomyName};
    
    # Recursive function to flatten the tree
    flattenTree = prefix: tree:
      l.flatten (
        [prefix] ++
        (l.mapAttrsToList (name: node:
          flattenTree "${prefix}/${name}" node
        ) (tree.children or {}))
      );
    
    # Start with each top-level category
    allPaths = l.flatten (l.mapAttrsToList (name: node:
      flattenTree name node
    ) taxonomy.categories);
  in
    allPaths;
  
  # Generate package with all registry functions
  registryPackage = pkgs: pkgs.writeTextFile {
    name = "taxonomy-registry";
    text = builtins.toJSON {
      taxonomies = l.mapAttrs (name: taxonomy: {
        inherit (taxonomy) name description format;
      }) taxonomies;
    };
    destination = "/share/taxonomies/registry.json";
  };
  
in {
  # Registry data
  taxonomies = taxonomies;
  
  # Lookup functions
  lookup = lookupCategory;
  list = listCategories;
  
  # Package generator
  package = registryPackage;
}