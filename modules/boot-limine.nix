{
  config,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    sbctl
    plymouth
  ];

  # Limine Configuration with plymouth
  boot = {
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "udev.log_level=0"
      "splash"
      "loglevel=0"
      "systemd.show_status=0"
      "vt.global_cursor_default=0"
    ];
    initrd = {
      systemd = {
        enable = true;
      };
      verbose = false;
    };
    loader = {
      limine = {
        enable = true;
        configurationLimit = 10;
        efiSupport = pkgs.stdenv.hostPlatform.isEfi;
        enrollConfig = boot.loader.limine.panicOnChecksumMismatch;
        secureBoot = {
          enable = true;
        };
        style = {
          backdrop = "1a1b26";
          graphicalTerminal = {
            foreground = "c0caf5";
            background = "1a1b26";
            brightForeground = "c0caf5";
            brightBackground = "1a1b26";
            palette = "15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6";
            brightPalette = "414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5";
          };
          interface = {
            branding = "NixOS Bootloader";
            brandingColor = "9ece6a";
          };
        }
      };
      efi = {
        efiSysMountPoint = "/boot";
        canTouchEfiVariables = true;
      };
    };
    plymouth = lib.mkIf (config.role == "desktop") {
      enable = true;
    };
  };
}
