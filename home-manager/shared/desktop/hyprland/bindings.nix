{ lib, ... }:
let
  inherit (lib.generators) mkLuaInline toLua;
  inherit (lib.lists) genList;

  browser = "zen-twilight";
  editor = "codium";
  lua = mkLuaInline;
  luaValue = toLua { multiline = false; };
  mkBind = keys: dispatcher: description: {
    _args = [
      keys
      (lua dispatcher)
      (lua "{ description = ${luaValue description} }")
    ];
  };
  mkExecBind =
    keys: command: description:
    mkBind keys "hl.dsp.exec_cmd(${luaValue command})" description;
  workspaceBindings = genList (
    index:
    let
      keycode = toString (10 + index);
      workspace = toString (index + 1);
    in
    mkBind "SUPER + SHIFT + ALT + code:${keycode}"
      "hl.dsp.window.move({ workspace = ${workspace}, follow = false })"
      "Move window silently to workspace ${workspace}"
  ) 10;
in
{
  wayland.windowManager.hyprland.settings.bind = [
    # APPLICATION LAUNCHERS
    (mkExecBind "SUPER + SHIFT + F" "uwsm-app -- nautilus --new-window" "File manager")
    (mkExecBind "SUPER + SHIFT + B" "uwsm-app -- ${browser}" "Browser")
    (mkExecBind "SUPER + SHIFT + ALT + B" "setsid uwsm-app -- ${browser} --private-window"
      "Browser (private)"
    )
    (mkExecBind "SUPER + SHIFT + N" "uwsm-app -- ${editor}" "Editor")
    (mkExecBind "SUPER + SHIFT + T" "dms ipc call widget toggle cpuUsage" "Activity")
    (mkExecBind "SUPER + SHIFT + G" "launch-or-focus '^[Bb]eeper(texts)?$' -- beeper" "Beeper")
    (mkExecBind "SUPER + SHIFT + O" "launch-or-focus '^obsidian$' -- obsidian" "Obsidian")
    (mkExecBind "SUPER + SHIFT + M"
      "launch-or-focus '^[Mm]attermost([\\.-][Dd]esktop)?$' -- mattermost-desktop"
      "Mattermost"
    )
    (mkExecBind "SUPER + CTRL + W" "dms ipc call widget toggle controlCenterButton" "WiFi")
    (mkExecBind "SUPER + CTRL + B" "dms ipc call widget toggle controlCenterButton" "Bluetooth")

    # WORKSPACE MANAGEMENT
    (mkBind "SUPER + S" ''hl.dsp.workspace.toggle_special("scratchpad")'' "Toggle scratchpad")
    (mkBind "SUPER + ALT + S"
      ''hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })''
      "Move window to scratchpad"
    )
    (mkBind "SUPER + CTRL + TAB" ''hl.dsp.focus({ workspace = "previous" })'' "Former workspace")
    (mkExecBind "SUPER + SHIFT + ALT + LEFT" "hyprctl dispatch movecurrentworkspacetomonitor l"
      "Move workspace to left monitor"
    )
    (mkExecBind "SUPER + SHIFT + ALT + RIGHT" "hyprctl dispatch movecurrentworkspacetomonitor r"
      "Move workspace to right monitor"
    )
    (mkExecBind "SUPER + SHIFT + ALT + UP" "hyprctl dispatch movecurrentworkspacetomonitor u"
      "Move workspace to up monitor"
    )
    (mkExecBind "SUPER + SHIFT + ALT + DOWN" "hyprctl dispatch movecurrentworkspacetomonitor d"
      "Move workspace to down monitor"
    )
    (mkBind "SUPER + SHIFT + code:20" "hl.dsp.window.resize({ x = 0, y = -100, relative = true })"
      "Shrink window up"
    )
    (mkBind "SUPER + SHIFT + code:21" "hl.dsp.window.resize({ x = 0, y = 100, relative = true })"
      "Expand window down"
    )
    (mkBind "SUPER + BACKSPACE" ''hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" })''
      "Toggle window transparency"
    )
  ]
  ++ workspaceBindings;
}
