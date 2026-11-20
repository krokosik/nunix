{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  gamingSession = getExe config.system.build.sunshineGamingSession;
in
{
  imports = singleton ../../modules/desktop/sunshine-gaming.nix;

  services.sunshine = {
    enable = true;

    settings.encoder = "nvenc";

    applications.apps = singleton {
      name = "Hookshot";
      cmd = "${config.users.users.${config.nunix.self.user}.home}/media/games/Hookshot/bin/hookshot";
      working-dir = "${config.users.users.${config.nunix.self.user}.home}/media/games/Hookshot";
      image-path = "${
        config.users.users.${config.nunix.self.user}.home
      }/media/games/Hookshot/hookshot.png";
      auto-detach = false;
      prep-cmd = singleton {
        do = "${gamingSession} prepare";
        undo = "${gamingSession} restore";
      };
    };
  };
}
