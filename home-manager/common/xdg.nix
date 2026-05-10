{
  config,
  pkgs,
  ...
}:
{
  xdg = {
    enable = true;
  };

  home.packages = [ pkgs.xdg-utils pkgs.xdg-terminal-exec ];
  xdg.mime.enable = true;

  xdg.terminalExec.enable = true;
  xdg.terminalExec.settings.default = [
    "ghostty.desktop"
    "alacritty.desktop"
    "kitty.desktop"
  ];

  xdg.userDirs = {
    enable = true;
    desktop = "${config.home.homeDirectory}";
    documents = "${config.home.homeDirectory}/docs";
    download = "${config.home.homeDirectory}/downloads";
    music = "${config.home.homeDirectory}/media/music";
    pictures = "${config.home.homeDirectory}/media/pictures";
    publicShare = "${config.home.homeDirectory}";
    videos = "${config.home.homeDirectory}/media/videos";
    templates = "${config.home.homeDirectory}";
    extraConfig = {
      XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/media/screenshots";
    };
  };
}