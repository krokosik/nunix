{
  inputs,
  outputs,
  pkgs,
  ...
}:
{
  # Home-manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit inputs outputs pkgs;
    };
    sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
  };
}
