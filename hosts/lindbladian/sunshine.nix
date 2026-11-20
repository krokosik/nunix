{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;

  gamingSession = getExe config.system.build.sunshineGamingSession;
  sunshine = getExe config.services.sunshine.package;
  stateDir = "${config.users.users.${config.nunix.self.user}.home}/.local/state/sunshine-gaming";

  apps = (pkgs.formats.json { }).generate "sunshine-gaming-apps.json" {
    env = { };
    apps = singleton {
      name = "Gaming Desktop";
      prep-cmd = singleton {
        do = "${gamingSession} prepare";
        undo = "${gamingSession} restore";
      };
    };
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
