{
  wayland.windowManager.hyprland.settings = {
    dwindle = {
      preserve_split = true;
      force_split = 2;
    };

    xwayland.force_zero_scaling = true;
    ecosystem = {
      no_update_news = true;
      no_donation_nag = true;
    };

    master.new_status = "master";
    misc = {
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      disable_scale_notification = true;
      focus_on_activate = true;
      anr_missed_pings = 3;
      enable_anr_dialog = false;
      on_focus_under_fullscreen = 1;
    };

    cursor.hide_on_key_press = true;
    binds.hide_special_on_workspace_change = true;
    workspace = [
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];
    windowrule = [
      "border_size 0, match:float 0, match:workspace w[tv1]"
      "rounding 0, match:float 0, match:workspace w[tv1]"
      "border_size 0, match:float 0, match:workspace f[1]"
      "rounding 0, match:float 0, match:workspace f[1]"
    ];
  };
}
