{ lib, ... }:
let
  inherit (lib.modules) mkAfter;
in
{
  imports = [
    ./animations.nix
    ./bindings.nix
    ./input.nix
    ./looknfeel.nix
    ./shell-utils.nix
    ./window-rules.nix
    ./windows.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;

    # NixOS installs and configures the portals alongside Hyprland.
    portalPackage = null;

    configType = "lua";

    settings.config.master.mfact = 0.5;

    extraConfig = mkAfter /* lua */ ''
      -- DMS-generated files intentionally load last and remain dynamic.
      require("dms.colors")
      require("dms.outputs")
      require("dms.layout")
      require("dms.cursor")
      require("dms.binds")
      require("dms.binds-user")
      require("dms.windowrules")
    '';
  };
}
