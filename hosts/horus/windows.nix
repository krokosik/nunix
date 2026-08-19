{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;

  systemd.services.windows-fonts = {
    description = "Install Windows fonts from the mounted Windows drive";
    wantedBy = [ "multi-user.target" ];
    after = [ "mnt-c.mount" ];
    wants = [ "mnt-c.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = /* bash */ ''
      install -d -m 0755 /usr/local/share/fonts
      ln -sfn /mnt/c/Windows/Fonts /usr/local/share/fonts/WindowsFonts
      ${pkgs.fontconfig}/bin/fc-cache --force /usr/local/share/fonts/WindowsFonts
    '';
  };

  fileSystems."/mnt/c" = {
    device = "/dev/disk/by-uuid/54E87E4BE87E2AFE";
    fsType = "ntfs3";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.device-timeout=5s"
      "windows_names"
      "uid=1000"
      "gid=100"
      "umask=0022"
    ];
  };
}
