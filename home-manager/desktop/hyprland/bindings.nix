{ ... }:
let
  browser = "zen-twilight";
  editor = "codium";
  workspaceBindings = builtins.concatLists (
    builtins.genList (index: [
      "SUPER SHIFT ALT, code:${toString (10 + index)}, Move window silently to workspace ${toString (index + 1)}, movetoworkspacesilent, ${toString (index + 1)}"
    ]) 10
  );
in
{
  wayland.windowManager.hyprland.settings.bindd = [
    # APPLICATION LAUNCHERS
    "SUPER SHIFT, F, File manager, exec, uwsm-app -- nautilus --new-window"
    "SUPER SHIFT, B, Browser, exec, uwsm-app -- ${browser}"
    "SUPER SHIFT ALT, B, Browser (private), exec, setsid uwsm-app -- ${browser} --private-window"
    "SUPER SHIFT, N, Editor, exec, uwsm-app -- ${editor}"
    "SUPER SHIFT, T, Activity, exec, dms ipc call widget toggle cpuUsage"
    "SUPER SHIFT, G, Beeper, exec, launch-or-focus '^[Bb]eeper(texts)?$' -- beeper"
    "SUPER SHIFT, O, Obsidian, exec, launch-or-focus '^obsidian$' -- obsidian"
    "SUPER SHIFT, M, Mattermost, exec, launch-or-focus '^[Mm]attermost([\.-][Dd]esktop)?$' -- mattermost-desktop"
    "SUPER CTRL, W, WiFi, exec, dms ipc call widget toggle controlCenterButton"
    "SUPER CTRL, B, Bluetooth, exec, dms ipc call widget toggle controlCenterButton"

    

    # WORKSPACE MANAGEMENT
    "SUPER, S, Toggle scratchpad, togglespecialworkspace, scratchpad"
    "SUPER ALT, S, Move window to scratchpad, movetoworkspacesilent, special:scratchpad"
    "SUPER CTRL, TAB, Former workspace, workspace, previous"
    "SUPER SHIFT ALT, LEFT, Move workspace to left monitor, movecurrentworkspacetomonitor, l"
    "SUPER SHIFT ALT, RIGHT, Move workspace to right monitor, movecurrentworkspacetomonitor, r"
    "SUPER SHIFT ALT, UP, Move workspace to up monitor, movecurrentworkspacetomonitor, u"
    "SUPER SHIFT ALT, DOWN, Move workspace to down monitor, movecurrentworkspacetomonitor, d"
    "SUPER SHIFT, code:20, Shrink window up, resizeactive, 0 -100"
    "SUPER SHIFT, code:21, Expand window down, resizeactive, 0 100"
  ]
  ++ workspaceBindings;
}
