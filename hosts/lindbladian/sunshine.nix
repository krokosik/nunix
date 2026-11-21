{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) escapeShellArg;

  gamingSession = getExe config.system.build.sunshineGamingSession;
  sunshine = getExe config.services.sunshine.package;
  stateDir = "${config.users.users.${config.nunix.self.user}.home}/.local/state/sunshine-gaming";
  hookshotDirectory = "${config.users.users.${config.nunix.self.user}.home}/media/games/Hookshot/bin";
  hookshot = escapeShellArg "${hookshotDirectory}/hookshot";
  launchHookshot = pkgs.writeShellScript "launch-hookshot" /* bash */ ''
    set -e
    cd -- ${escapeShellArg hookshotDirectory}
    exec ${hookshot}
  '';

  prepareGamingSession = {
    do = "${gamingSession} prepare";
    undo = "${gamingSession} restore";
  };

  apps = (pkgs.formats.json { }).generate "sunshine-gaming-apps.json" {
    env = { };
    apps = [
      {
        name = "Gaming Desktop";
        output = "${stateDir}/applications.log";
        prep-cmd = singleton prepareGamingSession;
      }
      {
        name = "Hookshot";
        output = "${stateDir}/applications.log";
        cmd = "${launchHookshot}";
        auto-detach = false;
        prep-cmd = [
          { do = "${getExe' pkgs.coreutils "test"} -x ${hookshot}"; }
          prepareGamingSession
        ];
      }
    ];
  };

  settings = (pkgs.formats.keyValue { }).generate "sunshine-gaming.conf" {
    sunshine_name = "lindbladian Gaming";
    port = 48089;
    capture = "wlr";
    output_name = "SUNSHINE";
    encoder = "nvenc";
    file_apps = "${apps}";
    credentials_file = "${stateDir}/state.json";
    file_state = "${stateDir}/state.json";
    pkey = "${stateDir}/cakey.pem";
    cert = "${stateDir}/cacert.pem";
    log_path = "${stateDir}/sunshine.log";
    origin_web_ui_allowed = "pc";
  };
in
{
  imports = singleton ../../modules/desktop/sunshine-gaming.nix;

  desktop.sunshineGaming = {
    separateInstance = true;
    pauseSystemUnits = singleton "whisper-server.service";
  };

  security.polkit.extraConfig = /* javascript */ ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "${config.nunix.self.user}" &&
          action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "whisper-server.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop")) {
        return polkit.Result.YES;
      }
    });
  '';

  services.sunshine.settings.output_name = "DP-1";

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      48084
      48089
      48110
    ];
    allowedUDPPorts = [
      48098
      48099
      48100
      48102
      48110
    ];
  };

  systemd.user.services.sunshine-gaming = {
    description = "Sunshine virtual gaming display";
    after = singleton "graphical-session.target";
    partOf = singleton "graphical-session.target";
    wantedBy = singleton "graphical-session.target";

    environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

    serviceConfig = {
      StateDirectory = "sunshine-gaming";
      StateDirectoryMode = "0700";
      ExecStart = "${sunshine} ${settings}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
