{
  boot.kernel.sysctl = {
    # Increase inotify file watchers for VS Code, webpack, and other dev tools (default 8192 is too low)
    "fs.inotify.max_user_watches" = 524288;
  };
}
