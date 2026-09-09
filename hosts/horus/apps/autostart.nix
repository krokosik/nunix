{
  wayland.windowManager.hyprland = {
    settings.exec-once = [
      "[silent] uwsm-app -- obsidian"
      "[silent] uwsm-app -- protonvpn-app"
      "[silent] uwsm-app -- mattermost-desktop"
      "[silent] uwsm-app -- beeper"
    ];
    extraConfig = ''
      # assign workspaces to monitors
      workspace=name:1, monitor:desc:Dell Inc. DELL S2725QS 3H8D364
      workspace=name:2, monitor:desc:BOE 0x0A1C
      exec-once = hyprctl dispatch workspace 1
    '';
  };
}
