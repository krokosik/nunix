{
  config,
  pkgs,
  ...
}:
{
  users.users.root = {
    ## hash: mkpasswd -m SHA-512 -s (initial password: rootpassword)
    initialHashedPassword = "$6$foNFb4DIEmWrZKtq$TZj8iVMQ40/JSO8or9f89bi9j0wkwbwMSvJAMjB1SDo6dwtwa1sbTXka81MUthFTnG75.i.PO0jg8c5b8E1R50";
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
    # initial password: ${config.username}
    initialHashedPassword = "$6$rXrqzLpTR6HBpH/K$50Czgh8PFC4ewGoilgHEbeHdA6mxBp.Ch7kHZuY.103wcSP8jvsd5E.hiSy1nJbTXvMVUQXt.T.UpqxckmZzS/";
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
