{
  # supress logs between greeter and dms
  systemd.user.settings.Manager = {
    LogTarget = "journal";
    ShowStatus = false;
  };
}
