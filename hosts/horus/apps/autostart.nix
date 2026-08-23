{ pkgs, ... }:
let
  autostartApps = [
    {
      pkg = pkgs.obsidian;
      desktop = "obsidian.desktop";
    }
    {
      pkg = pkgs.protonvpn-gui;
      desktop = "protonvpn-app.desktop";
    }
    {
      pkg = pkgs.mattermost-desktop;
      desktop = "mattermost-desktop.desktop";
    }
    {
      pkg = pkgs.beeper;
      desktop = "beeper.desktop";
    }
  ];
in
{
  xdg.configFile = builtins.listToAttrs (
    map (app: {
      name = "autostart/${app.desktop}";
      value = {
        source = "${app.pkg}/share/applications/${app.desktop}";
      };
    }) autostartApps
  );
}
