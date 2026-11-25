{
  config,
  inputs,
  outputs,
  pkgs,
  ...
}:
{
  # HOME-MANAGER CONFIGURATION
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit inputs outputs pkgs;
    };

    # Applies to every Home Manager user; private and desktop modules are imported per host for the primary user only
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      ./shared/common
    ];

    backupFileExtension = "bak";

    # Shared modules only reach declared users, so always declare the primary one
    users.${config.nunix.self.user} = { };
  };
}
