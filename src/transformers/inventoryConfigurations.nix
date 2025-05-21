{
  nixpkgs,
  root,
  inventoryFile,
  deploy-rs,
}: let
  l = nixpkgs.lib // builtins;
  inventory = builtins.fromJSON (builtins.readFile inventoryFile);
in
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
