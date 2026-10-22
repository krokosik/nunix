{
  # Osiris exports its media dataset as the NFSv4 root.
  # Mount on demand so an unavailable server does not delay boot.
  fileSystems."/mnt/media" = {
    device = "osiris:/";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "ro"
      "nosuid"
      "nodev"
      "_netdev"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=15s"
    ];
  };
}
