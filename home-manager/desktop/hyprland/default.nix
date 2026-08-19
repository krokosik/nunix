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
      # MONITOR CONFIG
      monitor = , preferred, auto, auto

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

      # WINDOW RULES
      windowrule = tile on, match:class ^(org\\.wezfurlong\\.wezterm)$
      windowrule = rounding 12, match:class ^(org\\.gnome\\.)
      windowrule = tile on, match:class ^(gnome-control-center)$
      windowrule = tile on, match:class ^(pavucontrol)$
      windowrule = tile on, match:class ^(nm-connection-editor)$
      windowrule = float on, match:class ^(org\\.gnome\\.Calculator)$
      windowrule = float on, match:class ^(gnome-calculator)$
      windowrule = float on, match:class ^(galculator)$
      windowrule = float on, match:class ^(blueman-manager)$
      windowrule = float on, match:class ^(org\\.gnome\\.Nautilus)$
      windowrule = float on, match:class ^(xdg-desktop-portal)$
      windowrule = no_initial_focus on, match:class ^(steam)$, match:title ^(notificationtoasts)
      windowrule = pin on, match:class ^(steam)$, match:title ^(notificationtoasts)
      windowrule = float on, match:class ^(firefox)$, match:title ^(Picture-in-Picture)$
      windowrule = float on, match:class ^(zoom)$

      layerrule = no_anim on, match:namespace ^(quickshell)$
      layerrule = no_anim on, match:namespace ^dms:.*

      # DMS-generated files intentionally load last and remain dynamic.
      source = ${config.xdg.configHome}/hypr/dms/colors.conf
      source = ${config.xdg.configHome}/hypr/dms/outputs.conf
      source = ${config.xdg.configHome}/hypr/dms/layout.conf
      source = ${config.xdg.configHome}/hypr/dms/cursor.conf
      source = ${config.xdg.configHome}/hypr/dms/binds.conf
      source = ${config.xdg.configHome}/hypr/dms/windowrules.conf
    '';
  };
}
