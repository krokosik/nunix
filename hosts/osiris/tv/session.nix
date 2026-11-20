{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  tvPkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  disabledModules = [
    "services/desktop-managers/plasma6.nix"
    "services/display-managers/sddm.nix"
  ];

  # Scope the unstable package set to the GUI modules, keeping server packages stable.
  imports = [
    (
      {
        config,
        lib,
        utils,
        ...
      }:
      import "${inputs.nixpkgs-unstable}/nixos/modules/services/desktop-managers/plasma6.nix" {
        inherit config lib utils;
        pkgs = tvPkgs;
      }
    )
    (
      {
        config,
        lib,
        utils,
        ...
      }:
      import "${inputs.nixpkgs}/nixos/modules/services/display-managers/sddm.nix" {
        inherit config lib utils;
        pkgs = tvPkgs;
      }
    )
  ];

  services = {
    desktopManager.plasma6.enable = true;
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      sessionPackages = singleton tvPkgs.kdePackages.plasma-bigscreen;
      defaultSession = "plasma-bigscreen-wayland";
      autoLogin = {
        enable = true;
        user = "tv";
      };
    };
  };

  environment.systemPackages = with tvPkgs.kdePackages; [
    plasma-bigscreen
    # Bigscreen imports plasma-nm's QML module even without NetworkManager.
    plasma-nm
  ];
}
