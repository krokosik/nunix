{ config, ... }:
{
  imports = [
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
    configType = "hyprlang";

    extraConfig = /* hyprlang */ ''
      # ANIMATIONS
      animations {
        enabled = true
        animation = windowsIn, 1, 3, default
        animation = windowsOut, 1, 3, default
        animation = workspaces, 1, 5, default
        animation = windowsMove, 1, 4, default
        animation = fade, 1, 3, default
        animation = border, 1, 3, default
      }

      master {
        mfact = 0.5
      }

      layerrule = no_anim on, match:namespace ^(quickshell)$
      layerrule = no_anim on, match:namespace ^dms:.*

      # DMS-generated files intentionally load last and remain dynamic.
      source = ${config.xdg.configHome}/hypr/dms/colors.conf
      source = ${config.xdg.configHome}/hypr/dms/outputs.conf
      source = ${config.xdg.configHome}/hypr/dms/layout.conf
      source = ${config.xdg.configHome}/hypr/dms/cursor.conf
      source = ${config.xdg.configHome}/hypr/dms/binds.conf
      source = ${config.xdg.configHome}/hypr/dms/windowrules.conf

      # assign workspaces to monitors
      workspace=name:1, monitor:desc:Dell Inc. DELL S2725QS 3H8D364
      workspace=name:2, monitor:desc:BOE 0x0A1C
      exec-once = hyprctl dispatch workspace 1
    '';
  };
}
