{
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.class = ".*";
      suppress_event = "maximize";
    }
    {
      match.class = ".*";
      tag = "+default-opacity";
    }
    {
      match = {
        class = "^$";
        title = "^$";
        xwayland = true;
        float = true;
        fullscreen = false;
        pin = false;
      };
      no_focus = true;
    }
    {
      match.tag = "default-opacity";
      opacity = "0.97 0.9";
    }
  ];
}
