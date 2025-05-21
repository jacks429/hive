{
  inputs,
  nixpkgs,
  root,
}: {
  evaled,
  locatedConfig,
}: let
  l = nixpkgs.lib // builtins;
  inherit (inputs) deploy-rs;
  inherit (root) transformers;

  name = l.baseNameOf (l.toString locatedConfig);

  metaPath = locatedConfig + "/../metadata.nix";
  hasMeta = l.pathExists metaPath;
  meta =
    if hasMeta
    then import metaPath
    else {};

  isDarwin = evaled.config.bee.pkgs.stdenv.isDarwin;

  # Warning if someone tries to nixos-rebuild on this machine
  deployModules = l.map (l.setDefaultModuleLocation (./deployrsConfigurations.nix + ":deployModules")) [
    {
      environment.etc."nixos/configuration.nix".text = ''
        throw "This machine is managed by deploy-rs.";
      '';
    }
  ];

  config = {
    imports = [locatedConfig] ++ deployModules;
  };

  # Delegate to base transformers
  base =
    if isDarwin
    then
      transformers.darwinConfigurations {
        inherit evaled;
        locatedConfig = config;
      }
    else
      transformers.nixosConfigurations {
        inherit evaled;
        locatedConfig = config;
      };

  # Add full `bee` module context like other Hive transformers
  bee =
    evaled.config.bee
    // {
      _evaled = base;
      _unchecked =
        (
          if isDarwin
          then transformers.darwinConfigurations
          else transformers.nixosConfigurations
        ) {
          inherit evaled;
          locatedConfig = config // {config._module.check = false;};
        };
    };
in {
  inherit name bee;

  hostname = meta.hostname or "${name}.local";
  sshUser = meta.sshUser or "root";
  tags = meta.tags or [];

  profiles.system.path = deploy-rs.lib.activate.nixos base;

  userHooks = l.optionalAttrs (meta ? secretsProfile) {
    pre-activate = "sops-nix apply --profile ${meta.secretsProfile}";
  };
}
