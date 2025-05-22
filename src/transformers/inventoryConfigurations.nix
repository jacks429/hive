{
  nixpkgs,
  root,
  inventoryFile ? null,
  deploy-rs ? null,
}: let
  l = nixpkgs.lib // builtins;
  
  # Check if inventoryFile is provided and exists
  hasInventoryFile = inventoryFile != null && 
                     builtins.pathExists (toString inventoryFile);
  
  # Read inventory file if available, otherwise use empty object
  inventory = if hasInventoryFile 
              then builtins.fromJSON (builtins.readFile (toString inventoryFile))
              else {};
              
  # Check if deploy-rs is available
  hasDeployRs = deploy-rs != null;
in
  # Only process inventory if both inventoryFile and deploy-rs are available
  if hasInventoryFile && hasDeployRs then
    l.mapAttrs (name: meta: {
      hostname = meta.hostname;
      sshUser = meta.sshUser or "root";
      tags = meta.tags or [];

      profiles.system.path = deploy-rs.lib.activate.nixos root.nixosConfigurations.${name};

      userHooks = l.optionalAttrs (meta ? secretsProfile) {
        pre-activate = "sops-nix apply --profile ${meta.secretsProfile}";
      };
    })
    inventory
  else
    # Return empty attrset if requirements are not met
    {}
