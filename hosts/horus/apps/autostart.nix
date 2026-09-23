{
  wayland.windowManager.hyprland = {
    settings.workspace_rule = [
      {
        workspace = "name:1";
        monitor = "desc:Dell Inc. DELL S2725QS 3H8D364";
      }
      {
        workspace = "name:2";
        monitor = "desc:BOE 0x0A1C";
      }
    ];
    extraConfig = /* lua */ ''
      hl.on("hyprland.start", function()
        hl.exec_cmd("hyprctl dispatch workspace 1")
      end)
    '';
  };
}
