{
  config,
  pkgs,
  ...
}:
let
  browser = "zen.desktop";
  editor = "codium.desktop";
  fileManager = "org.gnome.Nautilus.desktop";
  imageViewer = "imv.desktop";
  mailClient = "HEY.desktop";
  vectorEditor = "org.inkscape.Inkscape.desktop";
  videoPlayer = "mpv.desktop";
in
{
  xdg.enable = true;

  home.packages = [
    pkgs.xdg-utils
    pkgs.xdg-terminal-exec
  ];
  xdg.mime.enable = true;

  xdg."terminal-exec".enable = true;
  xdg."terminal-exec".settings.default = [
    "ghostty.desktop"
    "alacritty.desktop"
    "kitty.desktop"
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png" = imageViewer;
      "image/jpeg" = imageViewer;
      "image/gif" = imageViewer;
      "image/webp" = imageViewer;
      "image/bmp" = imageViewer;
      "image/tiff" = imageViewer;

      "application/pdf" = browser;
      "text/html" = browser;
      "x-scheme-handler/http" = browser;
      "x-scheme-handler/https" = browser;
      "x-scheme-handler/about" = browser;
      "x-scheme-handler/unknown" = browser;
      "x-scheme-handler/chrome" = browser;
      "application/x-extension-htm" = browser;
      "application/x-extension-html" = browser;
      "application/x-extension-shtml" = browser;
      "application/xhtml+xml" = browser;
      "application/x-extension-xhtml" = browser;
      "application/x-extension-xht" = browser;

      "video/mp4" = videoPlayer;
      "video/x-msvideo" = videoPlayer;
      "video/x-matroska" = videoPlayer;
      "video/x-flv" = videoPlayer;
      "video/x-ms-wmv" = videoPlayer;
      "video/mpeg" = videoPlayer;
      "video/ogg" = videoPlayer;
      "video/webm" = videoPlayer;
      "video/quicktime" = videoPlayer;
      "video/3gpp" = videoPlayer;
      "video/3gpp2" = videoPlayer;
      "video/x-ms-asf" = videoPlayer;
      "video/x-ogm+ogg" = videoPlayer;
      "video/x-theora+ogg" = videoPlayer;
      "application/ogg" = videoPlayer;

      "text/plain" = editor;
      "text/english" = editor;
      "text/x-makefile" = editor;
      "text/x-c++hdr" = editor;
      "text/x-c++src" = editor;
      "text/x-chdr" = editor;
      "text/x-csrc" = editor;
      "text/x-java" = editor;
      "text/x-moc" = editor;
      "text/x-pascal" = editor;
      "text/x-tcl" = editor;
      "text/x-tex" = editor;
      "application/x-shellscript" = editor;
      "text/x-c" = editor;
      "text/x-c++" = editor;
      "application/xml" = editor;
      "text/xml" = editor;
      "text/csv" = editor;
      "application/json" = editor;

      "image/svg+xml" = vectorEditor;
      "inode/directory" = fileManager;
      "x-scheme-handler/mailto" = mailClient;
    };
    associations.added = {
      "x-scheme-handler/http" = [ browser ];
      "x-scheme-handler/https" = [ browser ];
      "text/html" = [ browser ];
      "image/svg+xml" = [ vectorEditor ];
      "text/csv" = [ editor ];
      "application/json" = [ editor ];
      "x-scheme-handler/chrome" = [ browser ];
    };
  };

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
    projects = "${config.home.homeDirectory}/work";
    extraConfig = {
      XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/media/screenshots";
    };
    setSessionVariables = true;
  };
}
