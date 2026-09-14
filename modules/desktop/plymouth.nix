{
  pkgs,
  lib,
  ...
}:
{
  # Limine Configuration with plymouth
  boot = {
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "udev.log_level=0"
      "systemd.show_status=0"
      "vt.global_cursor_default=0"
      # Silence the initrd systemd instance
      "rd.systemd.show_status=false"
      "rd.udev.log_level=0"
    ];
    initrd.verbose = false;
    plymouth.enable = true;
  };

  # hold on the plymouth splash screen for longer
  systemd.services = {
    plymouth-quit = {
      after = [ "multi-user.target" ];
      serviceConfig.ExecStart = [
        "${lib.getExe' pkgs.plymouth "plymouth"} quit --retain-splash"
      ];
    };
    plymouth-quit-wait.enable = false;

    plymouth-poweroff.wantedBy = [ "poweroff.target" ];
    plymouth-halt.wantedBy = [ "halt.target" ];
    plymouth-reboot.wantedBy = [ "reboot.target" ];
  };
}
