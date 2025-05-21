{
  nixpkgs,
  root,
}: let
  l = nixpkgs.lib // builtins;
  inherit (root) mkCommand;
in {
  name = "resourceProfiles";
  type = "resourceProfile";
  
  actions = {
    currentSystem,
    fragment,
    target,
    inputs,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
    profile = inputs.${fragment}.${target};
    
    # Generate JSON profile
    generateProfileJson = pkgs.writeTextFile {
      name = "${target}-profile.json";
      text = builtins.toJSON profile.resources;
    };
    
    # Create a command to output the profile
    outputProfile = pkgs.writeShellScriptBin "profile-${target}" ''
      cat ${generateProfileJson}
    '';
    
  in [
    (mkCommand currentSystem {
      name = "profile-${target}";
      description = "Output resource profile ${target} as JSON";
      package = outputProfile;
    })
  ];
}