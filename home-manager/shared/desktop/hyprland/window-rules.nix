{
  wayland.windowManager.hyprland.settings = {
    window_rule = [
      # BROWSER CLASSIFICATION, OPACITY, TILING, AND SCREEN SHARING
      {
        match.class = "((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)";
        tag = "+chromium-based-browser";
      }
      {
        match.class = "([fF]irefox|zen|librewolf)";
        tag = "+firefox-based-browser";
      }
      {
        match.tag = "chromium-based-browser";
        tag = "-default-opacity";
      }
      {
        match.tag = "firefox-based-browser";
        tag = "-default-opacity";
      }
      {
        match.class = "(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)";
        tag = "-chromium-based-browser";
      }
      {
        match.class = "(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)";
        tag = "-default-opacity";
      }
      {
        match.tag = "chromium-based-browser";
        tile = true;
        opacity = "1.0 0.97";
      }
      {
        match.tag = "firefox-based-browser";
        opacity = "1.0 0.97";
      }
      {
        match.title = ".*is sharing.*";
        workspace = "special silent";
      }

      # FREECAD ADDON MANAGER FLOATING BEHAVIOR
      {
        match = {
          class = "org.freecad.FreeCAD";
          title = "Addon Manager";
        };
        float = true;
      }
      {
        match.class = "org.freecad.FreeCAD";
        no_follow_mouse = true;
      }

      # INKSCAPE POPUP AND DOCUMENT-WINDOW BEHAVIOR
      {
        match.class = "org.inkscape.Inkscape";
        float = true;
      }
      {
        match.title = ".*( - Inkscape)$";
        float = false;
      }

      # LOCALSEND AND FILE-PICKER PLACEMENT
      {
        match.class = "(Share|localsend)";
        float = true;
        center = true;
      }

      # PICTURE-IN-PICTURE SIZING, PINNING, AND PLACEMENT
      {
        match.title = "(Picture.?in.?[Pp]icture)";
        tag = "+pip";
      }
      {
        match.tag = "pip";
        float = true;
        pin = true;
        size = [
          600
          338
        ];
        keep_aspect_ratio = true;
        border_size = 0;
        opacity = "1 1";
        move = [
          "monitor_w-window_w-40"
          "monitor_h*0.04"
        ];
      }

      # QEMU OPACITY EXCEPTIONS
      {
        match.class = "qemu";
        tag = "-default-opacity";
        opacity = "1 1";
      }

      # SCRATCHPAD APPLICATION PLACEMENT
      {
        match.class = "^((md\\.)?[Oo]bsidian|[Bb]eeper(texts)?|[Mm]attermost([\\.-][Dd]esktop)?)$";
        workspace = "special:scratchpad";
      }

      # STEAM WINDOW SIZING, FLOATING, OPACITY, AND IDLE INHIBITION
      {
        match.class = "steam";
        float = true;
        opacity = "1 1";
        idle_inhibit = "fullscreen";
      }
      {
        match = {
          class = "steam";
          title = "Steam";
        };
        center = true;
        size = [
          1100
          700
        ];
      }
      {
        match = {
          class = "steam";
          title = "Friends List";
        };
        size = [
          460
          800
        ];
      }
      {
        match = {
          class = "^(steam)$";
          title = "^(notificationtoasts)";
        };
        no_initial_focus = true;
        pin = true;
      }

      # GENERIC FLOATING DIALOGS AND MEDIA-WINDOW OPACITY
      {
        match.tag = "floating-window";
        float = true;
        center = true;
        size = [
          875
          600
        ];
      }
      {
        match.class = "(org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)";
        tag = "+floating-window";
      }
      {
        match = {
          class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)";
          title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*|File.*|Save.*)";
        };
        tag = "+floating-window";
      }
      {
        match.class = "(zenity|kdialog)";
        float = true;
      }
      {
        match.class = "org.gnome.Calculator";
        float = true;
      }
      {
        match.class = "tics pro.exe";
        float = true;
      }
      {
        match.class = "^(blender|FreeCad|OrcaSlicer|BambuStudio|zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$";
        tag = "-default-opacity";
        opacity = "1 1";
      }
      {
        match.class = "com.moonlight_stream.Moonlight";
        fullscreen = true;
        idle_inhibit = "fullscreen";
      }
      {
        match.class = "python3";
        float = true;
        size = [
          800
          600
        ];
        no_initial_focus = true;
      }
      {
        match.tag = "pop";
        rounding = 8;
      }
      {
        match.tag = "noidle";
        idle_inhibit = "always";
      }
      {
        match.class = "^(xdg-desktop-portal)$";
        float = true;
      }

      # TERMINAL TAGGING AND OPACITY
      {
        match.class = "(Alacritty|kitty|com.mitchellh.ghostty)";
        tag = "+terminal";
      }
      {
        match.tag = "terminal";
        tag = "-default-opacity";
        opacity = "0.97 0.9";
      }

      # WEBCAM OVERLAY PLACEMENT AND FOCUS BEHAVIOR
      {
        match.title = "WebcamOverlay";
        float = true;
        pin = true;
        no_initial_focus = true;
        no_dim = true;
        move = [
          "monitor_w-window_w-40"
          "monitor_h-window_h-40"
        ];
      }

      # WINE APPLICATION FLOATING BEHAVIOR
      {
        match.tag = "wine-window";
        float = true;
        center = true;
      }
      {
        match.class = "(.*\\.exe)$";
        tag = "+wine-window";
      }

      # ZOTERO POPUP AND MAIN-WINDOW TAGGING
      {
        match.class = "Zotero";
        tag = "+floating-window";
      }
      {
        match.title = ".*( - Zotero)$";
        tag = "-floating-window";
      }
      {
        match.title = "Zotero";
        tag = "-floating-window";
      }
    ];

    layer_rule = [
      {
        match.namespace = "selection";
        no_anim = true;
      }
      {
        match.namespace = "walker";
        no_anim = true;
      }
    ];
  };
}
