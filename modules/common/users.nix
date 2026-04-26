{
  config,
  pkgs,
  ...
}:
{
  users.mutableUsers = false;

  sops.secrets.login_password_hash.neededForUsers = true;

  users.users.root = {
    hashedPasswordFile = config.sops.secrets.login_password_hash.path;
  };

  users.defaultUserShell = pkgs.fish;
  programs.fish.enable = true;

  # Normal user
  users.users.${config.username} = {
    isNormalUser = true;
    group = "${config.username}";
    extraGroups = [
      "libvirtd"
      "networkmanager"
      "users"
      "wheel"
    ];
    uid = 1000;
    hashedPasswordFile = config.sops.secrets.login_password_hash.path;
    # keys: id_ed25519.pub
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKb4VxsZXBODsfl98C8eP4ofNQxrDv//KhhAhOLyRd2 krokosik@legion"
    ];
  };
  users.groups.${config.username} = {
    gid = 1000;
  };

  # Setup PAM to use SSH key as sudo auth if available.
  security = {
    sudo.execWheelOnly = true;

    pam = {
      rssh = {
        enable = true;
        settings.auth_key_file = "/etc/ssh/authorized_keys.d/${config.username}";
      };
      services.sudo.rssh = true;
    };
  };
}
