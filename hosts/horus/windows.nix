{
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
