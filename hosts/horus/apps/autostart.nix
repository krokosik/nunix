{ lib, ... }:
let
  inherit (lib.generators) mkLuaInline;
in
{
  wayland.windowManager.hyprland.settings = {
    workspace_rule = [
      {
        workspace = "1";
        monitor = "desc:Dell Inc. DELL S2725QS 3H8D364";
        default = true;
      }
      {
        workspace = "2";
        monitor = "desc:BOE 0x0A1C";
        default = true;
      }
    ];

    on._args = [
      "hyprland.start"
      (mkLuaInline ''
        function()
          hl.exec_cmd("hyprctl dispatch focusmonitor 'desc:Dell Inc. DELL S2725QS 3H8D364'")
          hl.exec_cmd("hyprctl dispatch workspace 1")
        end
      '')
    ];
  };
}
