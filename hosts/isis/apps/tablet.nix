{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  hyprlandPlugins = pkgs.hyprlandPlugins.override {
    hyprland = osConfig.programs.hyprland.package;
  };
in
{
  home.packages = singleton pkgs.iio-hyprland;

  wayland.windowManager.hyprland = {
    plugins = singleton hyprlandPlugins.hyprgrass;

    settings = {
      # Rotate the built-in panel and touch input using iio-sensor-proxy.
      exec-once = singleton "${getExe pkgs.iio-hyprland} eDP-1";

      plugin.touch_gestures = {
        # Upstream recommends higher sensitivity on tablet screens.
        sensitivity = 4.0;
        workspace_swipe_fingers = 3;
      };
    };
  };
}
