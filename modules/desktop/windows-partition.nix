{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) nullOr str;

  cfg = config.desktop.windows.partition;
  enabled = cfg.device != null && cfg.guid != null;
  mountPath = "/mnt/c";
in
{
  options.desktop.windows.partition = {
    device = mkOption {
      type = nullOr str;
      default = null;
      description = "Device path of the Windows NTFS partition.";
    };

    guid = mkOption {
      type = nullOr str;
      default = null;
      description = "Partition GUID of the EFI system partition containing Windows Boot Manager.";
    };
  };

  config = {
    fonts.fontconfig = mkIf enabled {
      enable = true;

      localConf = /* xml */ ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <dir>${mountPath}/Windows/Fonts</dir>
          <selectfont>
            <rejectfont>
              <pattern>
                <patelt name="family">
                  <string>8514fix</string>
                </patelt>
              </pattern>
            </rejectfont>
          </selectfont>
        </fontconfig>
      '';
    };

    fileSystems.${mountPath} = mkIf enabled {
      inherit (cfg) device;
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

    boot.loader.limine.extraEntries = mkIf enabled /* limine */ ''
      /Windows 11
          protocol: efi_chainload
          image_path: guid(${cfg.guid}):/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
