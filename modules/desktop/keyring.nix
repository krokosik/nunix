{
  security.pam.services = {
    dms-greeter.enableGnomeKeyring = true;
    login.enableGnomeKeyring = true;
  };

  services.gnome.gnome-keyring.enable = true;
}
