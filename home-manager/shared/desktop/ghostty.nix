{ ... }:
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      window-padding-x = 14;
      window-padding-y = 14;
      confirm-close-surface = false;
      resize-overlay = "never";
      cursor-style = "block";
      cursor-style-blink = false;
      shell-integration-features = "no-cursor";
      mouse-scroll-multiplier = 0.95;
      async-backend = "epoll";
      keybind = [
        "f11=toggle_fullscreen"
        "shift+insert=paste_from_clipboard"
        "control+insert=copy_to_clipboard"
        "shift+enter=csi:13;2u"
        "alt+shift+enter=csi:13;4u"
        "super+control+shift+alt+arrow_down=resize_split:down,100"
        "super+control+shift+alt+arrow_up=resize_split:up,100"
        "super+control+shift+alt+arrow_left=resize_split:left,100"
        "super+control+shift+alt+arrow_right=resize_split:right,100"
      ];
    };
  };
}
