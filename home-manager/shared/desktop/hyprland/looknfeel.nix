{
  wayland.windowManager.hyprland.settings = {
    config = {
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
    };

    # workspace_rule = [
    #   {
    #     workspace = "w[tv1]";
    #     gaps_out = 0;
    #     gaps_in = 0;
    #   }
    #   {
    #     workspace = "f[1]";
    #     gaps_out = 0;
    #     gaps_in = 0;
    #   }
    # ];
    # window_rule = [
    #   {
    #     match = {
    #       float = false;
    #       workspace = "w[tv1]";
    #     };
    #     border_size = 0;
    #     rounding = 0;
    #   }
    #   {
    #     match = {
    #       float = false;
    #       workspace = "f[1]";
    #     };
    #     border_size = 0;
    #     rounding = 0;
    #   }
    # ];
  };
}
