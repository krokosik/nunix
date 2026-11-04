{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkForce;
  printfExe = getExe' pkgs.coreutils "printf";
in
{
  # LIMINE CONFIGURATION WITH PLYMOUTH
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
      after = singleton "multi-user.target";
      serviceConfig.ExecStart = mkForce (
        singleton "-${getExe' pkgs.plymouth "plymouth"} quit --retain-splash"
      );
    };
    # We do not want boot to wait for splash to be dismissed
    plymouth-quit-wait.enable = false;

    plymouth-poweroff.wantedBy = singleton "poweroff.target";
    plymouth-halt.wantedBy = singleton "halt.target";
    plymouth-reboot.wantedBy = singleton "reboot.target";

    clear-tty-on-shutdown = {
      description = "Clear TTY to hide text flashes during shutdown handoff";
      before = [
        "plymouth-poweroff.service"
        "plymouth-reboot.service"
        "plymouth-halt.service"
      ];
      wantedBy = [
        "poweroff.target"
        "reboot.target"
        "halt.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        # \033[2J clears the screen, \033[3J clears the scrollback, \033[H moves cursor to 0,0
        ExecStart = "${printfExe} '\\033[2J\\033[3J\\033[H'";
        StandardOutput = "tty";
        TTYPath = "/dev/tty1";
      };
    };
  };
}
