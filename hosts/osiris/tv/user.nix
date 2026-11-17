{
  users.users.tv = {
    isNormalUser = true;
    hashedPassword = "!";
    description = "TV session";
  };

  home-manager.users.tv = {
    home.stateVersion = "26.05";
    xdg.configFile."kscreenlockerrc".text = /* ini */ ''
      [Daemon]
      Autolock=false
      LockOnResume=false
    '';
  };
}
