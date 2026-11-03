{
  inputs,
  lib,
  outputs,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  # HOME-MANAGER CONFIGURATION
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit inputs outputs pkgs;
    };
    sharedModules = singleton inputs.sops-nix.homeManagerModules.sops;
  };
}
