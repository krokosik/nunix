{
  wayland.windowManager.hyprland.settings = {
    config.input = {
      kb_layout = "pl";
      kb_options = "compose:caps";
      repeat_rate = 40;
      repeat_delay = 600;
      follow_mouse = 1;
      numlock_by_default = true;
      sensitivity = -0.3;
      touchpad = {
        natural_scroll = true;
        scroll_factor = 0.4;
      };
    };

    window_rule = [
      {
        match.class = "(Alacritty|kitty)";
        scroll_touchpad = 1.5;
      }
      {
        match.class = "com.mitchellh.ghostty";
        scroll_touchpad = 0.2;
      }
    ];
  };
}
