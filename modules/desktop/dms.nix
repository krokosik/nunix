{ pkgs, ... }:

{
  programs.dms-shell = {
    enable = true;
    enableAudioWavelength = true;
    enableCalendarEvents = false;
    enableSystemMonitoring = true;
    enableVPN = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    # For sha, use nix store prefetch-file --unpack --json <link to tar.gz>
    plugins = {
      screenRecorderLH = {
        src = pkgs.fetchFromGitHub {
          owner = "hthienloc";
          repo = "dms-screen-recorder";
          rev = "v1.1";
          sha256 = "sha256-Gd7beNQYGnSlEyyE3hRnHEWXOhIMqlA1TNL1fFJR2FE=";
        };
      };
    };
  };

}
