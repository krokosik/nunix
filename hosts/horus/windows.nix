let
  mountPath = "/mnt/c";
in
{
  fonts.fontconfig = {
    enable = true;

    localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <dir>${mountPath}/Windows/Fonts</dir>
      </fontconfig>
    '';
  };

  fileSystems.${mountPath} = {
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

  boot.loader.limine.extraEntries = ''
    /Windows 11
        protocol: efi_chainload
        image_path: guid(45957aa2-3cc2-4a30-a487-ecb327670d56):/EFI/Microsoft/Boot/bootmgfw.efi
  '';
}
