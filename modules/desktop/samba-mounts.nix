{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.strings) removePrefix;
  inherit (lib.types) bool;
in
{
  options.desktop.sambaMounts.allUsers = mkOption {
    type = bool;
    default = false;
    description = "Allow all local users in the users group to access the Qotex shares";
  };

  config = {
    environment.systemPackages = singleton pkgs.cifs-utils;

    sops.secrets.samba_qot_credentials = {
      key = "samba/qot";
      mode = "0400";
      sopsFile = "${inputs.my-secrets}/desktop/secrets.yaml";
    };

    fileSystems = genAttrs [ "/mnt/data" "/mnt/assets" ] (mountPoint: {
      device = "//qotex.qot.internal/${removePrefix "/mnt/" mountPoint}";
      fsType = "cifs";
      options = [
        "rw"
        "_netdev"
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=120s"
        "x-systemd.mount-timeout=10s"
        "credentials=${config.sops.secrets.samba_qot_credentials.path}"
        "vers=3"
        "uid=${config.username}"
        "gid=${
          if config.desktop.sambaMounts.allUsers then "users" else config.users.users.${config.username}.group
        }"
        "forceuid"
        "forcegid"
        "nounix"
        "perm"
        "file_mode=0660"
        "dir_mode=0770"
        "nosuid"
        "nodev"
      ];
    });

    home-manager.users.${config.username} = { config, ... }: {
      home.file = genAttrs [ "data" "assets" ] (share: {
        source = config.lib.file.mkOutOfStoreSymlink "/mnt/${share}";
      });
    };
  };
}
