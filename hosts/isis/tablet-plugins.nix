{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkOrder;
  inherit (lib.strings) makeBinPath;
  hyprgrass =
    (pkgs.hyprlandPlugins.override { hyprland = config.programs.hyprland.package; })
    .hyprgrass.overrideAttrs
      (old: {
        # Stable's source predates Hyprland's Lua API. Keep the exact host ABI.
        inherit
          (inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.hyprlandPlugins.hyprgrass
          )
          version
          src
          ;
        buildInputs = (old.buildInputs or [ ]) ++ [
          pkgs.libpulseaudio
          pkgs.glibmm
          pkgs.systemd
        ];
        mesonFlags = (old.mesonFlags or [ ]) ++ [
          "-Dhyprgrass-pulse=true"
          "-Dhyprgrass-backlight=true"
        ];
        # Border holds should not resize tiled gaps in the scrolling layout.
        postPatch = (old.postPatch or "") + /* bash */ ''
          substituteInPlace src/GestureManager.cpp \
            --replace-fail 'if (w && !w->isFullscreen()) {' \
              'if (w && w->m_isFloating && !w->isFullscreen()) {'
        '';
      });
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
      wayland.windowManager.hyprland.plugins = [
        hyprgrass
        "${hyprgrass}/lib/libhyprgrass-pulse.so"
        "${hyprgrass}/lib/libhyprgrass-backlight.so"
      ];

      # Load after DMS's dynamic Lua so laptop-mode values can be restored.
      wayland.windowManager.hyprland.extraConfig = mkOrder 1501 /* lua */ ''
        dofile("${./tablet-mode/gestures.lua}")
      '';

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
