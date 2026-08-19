let
  browser = "zen-twilight";
  editor = "codium";
in
{
  wayland.windowManager.hyprland.settings = {
    bindd = [
      # APPLICATION LAUNCHERS
      "SUPER SHIFT, F, File manager, exec, uwsm-app -- nautilus --new-window"
      "SUPER SHIFT, B, Browser, exec, uwsm-app -- ${browser}"
      "SUPER SHIFT ALT, B, Browser (private), exec, setsid uwsm-app -- ${browser} --private-window"
      "SUPER SHIFT, N, Editor, exec, uwsm-app -- ${editor}"
      "SUPER SHIFT, T, Activity, exec, dms ipc call widget toggle cpuUsage"
      "SUPER SHIFT, G, Beeper, exec, launch-or-focus Beeper -- uwsm-app -- beeper"
      "SUPER SHIFT, O, Obsidian, exec, launch-or-focus '^obsidian$' -- uwsm-app -- obsidian"
      "SUPER SHIFT, M, Mattermost, exec, launch-or-focus Mattermost -- uwsm-app -- mattermost-desktop"
      "SUPER CTRL, W, WiFi, exec, dms ipc call widget toggle controlCenterButton"
      "SUPER CTRL, B, Bluetooth, exec, dms ipc call widget toggle controlCenterButton"
    ];

    windowrule = [
      # Browser classification, opacity, tiling, and screen-sharing placement
      "tag +chromium-based-browser, match:class ((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)"
      "tag +firefox-based-browser, match:class ([fF]irefox|zen|librewolf)"
      "tag -default-opacity, match:tag chromium-based-browser"
      "tag -default-opacity, match:tag firefox-based-browser"
      "tag -chromium-based-browser, match:class (chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)"
      "tag -default-opacity, match:class (chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)"
      "tile on, match:tag chromium-based-browser"
      "opacity 1.0 0.97, match:tag chromium-based-browser"
      "opacity 1.0 0.97, match:tag firefox-based-browser"
      "workspace special silent, match:title .*is sharing.*"

      # FreeCAD addon manager floating behavior
      "float on, match:class org.freecad.FreeCAD, match:title Addon Manager"
      "no_follow_mouse on, match:class org.freecad.FreeCAD"

      # Inkscape popup and document-window behavior
      "float on, match:class org.inkscape.Inkscape"
      "float off, match:title .*( - Inkscape)$"

      # LocalSend and file-picker placement
      "float on, match:class (Share|localsend)"
      "center on, match:class (Share|localsend)"

      # Picture-in-picture sizing, pinning, and placement
      "tag +pip, match:title (Picture.?in.?[Pp]icture)"
      "float on, match:tag pip"
      "pin on, match:tag pip"
      "size 600 338, match:tag pip"
      "keep_aspect_ratio on, match:tag pip"
      "border_size 0, match:tag pip"
      "opacity 1 1, match:tag pip"
      "move (monitor_w-window_w-40) (monitor_h*0.04), match:tag pip"

      # QEMU opacity exceptions
      "tag -default-opacity, match:class qemu"
      "opacity 1 1, match:class qemu"

      # Scratchpad application placement
      "workspace special:scratchpad, match:class ^(obsidian|[Bb]eeper(texts)?|[Mm]attermost([\\.-][Dd]esktop)?)$"

      # Steam window sizing, floating, opacity, and idle inhibition
      "float on, match:class steam"
      "center on, match:class steam, match:title Steam"
      "opacity 1 1, match:class steam"
      "size 1100 700, match:class steam, match:title Steam"
      "size 460 800, match:class steam, match:title Friends List"
      "idle_inhibit fullscreen, match:class steam"

      # Generic floating dialogs and media-window opacity
      "float on, match:tag floating-window"
      "center on, match:tag floating-window"
      "size 875 600, match:tag floating-window"
      "tag +floating-window, match:class (org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)"
      "tag +floating-window, match:class (xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus), match:title ^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*|File.*|Save.*)"
      "float on, match:class (zenity|kdialog)"
      "float on, match:class org.gnome.Calculator"
      "float on, match:class tics pro.exe"
      "tag -default-opacity, match:class ^(blender|FreeCad|OrcaSlicer|BambuStudio|zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$"
      "opacity 1 1, match:class ^(blender|FreeCad|OrcaSlicer|BambuStudio|zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$"
      "fullscreen 1, match:class com.moonlight_stream.Moonlight"
      "idle_inhibit fullscreen, match:class com.moonlight_stream.Moonlight"
      "float on, match:class python3"
      "size 800 600, match:class python3"
      "no_initial_focus on, match:class python3"
      "rounding 8, match:tag pop"
      "idle_inhibit always, match:tag noidle"

      # Terminal tagging and opacity
      "tag +terminal, match:class (Alacritty|kitty|com.mitchellh.ghostty)"
      "tag -default-opacity, match:tag terminal"
      "opacity 0.97 0.9, match:tag terminal"

      # Webcam overlay placement and focus behavior
      "float on, match:title WebcamOverlay"
      "pin on, match:title WebcamOverlay"
      "no_initial_focus on, match:title WebcamOverlay"
      "no_dim on, match:title WebcamOverlay"
      "move (monitor_w-window_w-40) (monitor_h-window_h-40), match:title WebcamOverlay"

      # Wine application floating behavior
      "float on, match:tag wine-window"
      "center on, match:tag wine-window"
      "tag +wine-window, match:class (.*\\.exe)$"

      # Zotero popup and main-window tagging
      "tag +floating-window, match:class Zotero"
      "tag -floating-window, match:title .*( - Zotero)$"
      "tag -floating-window, match:title Zotero"
    ];

    layerrule = [
      # Screenshot selection layer animation
      "no_anim on, match:namespace selection"

      # Walker layer animation
      "no_anim on, match:namespace walker"
    ];
  };
}
