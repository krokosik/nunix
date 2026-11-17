{
  security.polkit.extraConfig = /* javascript */ ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "tv" &&
          (action.id.indexOf("org.freedesktop.login1.power-off") == 0 ||
           action.id.indexOf("org.freedesktop.login1.reboot") == 0 ||
           action.id.indexOf("org.freedesktop.login1.suspend") == 0 ||
           action.id.indexOf("org.freedesktop.login1.hibernate") == 0 ||
           action.id.indexOf("org.freedesktop.login1.hybrid-sleep") == 0 ||
           action.id == "org.freedesktop.systemd1.manage-units")) {
        return polkit.Result.NO;
      }
    });
  '';

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    IdleAction = "ignore";
  };

  systemd = {
    sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };
  };

}
