{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) makeBinPath;
in
{
  programs.iio-hyprland = {
    enable = true;
    package = pkgs.iio-hyprland.overrideAttrs {
      version = "${pkgs.iio-hyprland.version}-lua";
      src = pkgs.fetchFromGitHub {
        owner = "ThorTuwy";
        repo = "lua-iio-hyprland";
        rev = "c5f55e49d0bc54d51c8f9c34e0e8fb2f640bd4b3";
        hash = "sha256-/daGR3X0l6TniCNRzXCSyX2N5mqVLN0n8LWe0Ki2U3w=";
      };
    };
  };

  home-manager.users.${config.username} =
    { config, osConfig, ... }:
    {
      # The tablet watcher owns activation; no login enablement or layout changes.
      systemd.user.services.surface-tablet-rotation = {
        Unit = {
          Description = "Surface tablet display and input rotation";
          PartOf = [
            config.wayland.systemd.target
            "surface-tablet-mode.service"
          ];
          ConditionPathExists = "%t/surface-tablet/tablet";
        };
        Service = {
          ExecStart = "${getExe osConfig.programs.iio-hyprland.package} eDP-1";
          Environment = singleton "PATH=${
            makeBinPath [
              pkgs.hyprland
              pkgs.jq
            ]
          }";
          ExecStopPost = "${getExe' pkgs.hyprland "hyprctl"} eval 'hl.monitor({output = \"eDP-1\", transform = 0}); hl.config({input = {touchdevice = {transform = 0}, tablet = {transform = 0}}})'";
          Restart = "always";
          RestartSec = 2;
          NoNewPrivileges = true;
        };
      };
    };
}
