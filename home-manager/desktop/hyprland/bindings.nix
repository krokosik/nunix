{ ... }:
let
  workspaceBindings = builtins.concatLists (
    builtins.genList (index: [
      "SUPER SHIFT ALT, code:${toString (10 + index)}, Move window silently to workspace ${toString (index + 1)}, movetoworkspacesilent, ${toString (index + 1)}"
    ]) 10
  );
in
{
  wayland.windowManager.hyprland.settings.bindd = [
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
