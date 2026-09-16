{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) genAttrs listToAttrs;
  inherit (lib.lists) elem;

  extraUserPasswordSecret = username: "extra_user_password_hash_${username}";
  extraUserPasswordSecrets = listToAttrs (
    map (username: {
      name = extraUserPasswordSecret username;
      value = {
        key = "login_password_hashes/${username}";
        neededForUsers = true;
      };
    }) config.extraUsers
  );
in
{
  assertions = [
    {
      assertion = !(elem config.username config.extraUsers);
      message = "The primary username must not also appear in extraUsers";
    }
  ];

  users.mutableUsers = false;

  sops.secrets = {
    login_password_hash.neededForUsers = true;
  }
  // extraUserPasswordSecrets;

  users.defaultUserShell = pkgs.fish;
  programs.fish.enable = true;

  users.users = {
    root = {
      hashedPasswordFile = config.sops.secrets.login_password_hash.path; # Create with: echo -n "password" | mkpasswd -s
    };

    ${config.username} = {
      isNormalUser = true;
      group = config.username;
      extraGroups = [
        "libvirtd"
        "networkmanager"
        "users"
        "wheel"
      ];
      uid = 1000;
      hashedPasswordFile = config.sops.secrets.login_password_hash.path; # Create with: echo -n "password" | mkpasswd -s
      # keys: id_ed25519.pub
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKb4VxsZXBODsfl98C8eP4ofNQxrDv//KhhAhOLyRd2 krokosik@legion"
      ];
    };
  }
  // genAttrs config.extraUsers (username: {
    isNormalUser = true;
    group = username;
    extraGroups = [
      "networkmanager"
      "users"
    ];
    hashedPasswordFile = config.sops.secrets.${extraUserPasswordSecret username}.path;
  });

  users.groups = {
    ${config.username}.gid = 1000;
  }
  // genAttrs config.extraUsers (_: { });

}
