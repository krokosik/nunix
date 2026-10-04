{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe getExe';
  inherit (lib.lists) singleton;
  upstreamDms = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
  python = pkgs.python3.withPackages (packages: singleton packages.evdev);
  wvkbd =
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.wvkbd.overrideAttrs
      (old: {
        # Upstream PR 126: prevent --auto from creating orphaned layer surfaces.
        patchFlags = [
          "--strip=1"
          "--fuzz=0"
        ];
        patches = (old.patches or [ ]) ++ [
          ./patches/wvkbd-auto-reentrancy.patch
          ./patches/wvkbd-input-method-done.patch
        ];
      });
in
{
  boot.kernelModules = singleton "surface_aggregator_tabletsw";

  # Access to this switch only; no additional input-group membership.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Microsoft Surface KIP Tablet Mode Switch", TAG+="uaccess"
  '';

  # Repackage runtime QML; reuse the upstream Go binary and Qt dependencies.
  programs.dank-material-shell.package =
    pkgs.runCommand "dms-surface-tablet"
      {
        meta.mainProgram = "dms";
      }
      /* bash */ ''
        cp --recursive ${upstreamDms}/. "$out"
        chmod --recursive u+w "$out"
        ${getExe pkgs.python3} ${./tablet-mode/patch-dms.py} "$out/share/quickshell/dms"
        substituteInPlace "$out/bin/dms" \
          --replace-fail '${upstreamDms}/share/quickshell/dms' "$out/share/quickshell/dms"
        substituteInPlace "$out/lib/systemd/user/dms.service" \
          --replace-fail '${upstreamDms}/bin/dms' "$out/bin/dms"
      '';

  home-manager.users.${config.username} =
    { config, osConfig, ... }:
    let
      watcherConfig = (pkgs.formats.json { }).generate "surface-tablet-mode.json" {
        hyprctl = getExe' pkgs.hyprland "hyprctl";
        dms = getExe osConfig.programs.dank-material-shell.package;
        systemctl = getExe' pkgs.systemd "systemctl";
        normalLayout = config.wayland.windowManager.hyprland.settings.config.general.layout or "dwindle";
        tabletServices = [
          "surface-tablet-osk.service"
          "surface-tablet-rotation.service"
        ];
      };
    in
    {
      # Home Manager emits hl.config({...}) in the existing Lua configuration.
      # Keep hardware detection and future touchscreen gestures separate.
      wayland.windowManager.hyprland.settings.config.scrolling = {
        column_width = 0.8;
        fullscreen_on_one_column = true;
        focus_fit_method = 1;
        follow_focus = true;
      };

      systemd.user.services.surface-tablet-mode = {
        Unit = {
          Description = "Surface tablet-mode session watcher";
          PartOf = singleton config.wayland.systemd.target;
          After = singleton config.wayland.systemd.target;
        };
        Service = {
          ExecStart = "${getExe python} ${./tablet-mode/watch.py} ${watcherConfig}";
          Restart = "on-failure";
          RestartSec = 2;
          RuntimeDirectory = "surface-tablet";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          UMask = "0077";
        };
        Install.WantedBy = singleton config.wayland.systemd.target;
      };

      # Deliberately not WantedBy: the switch watcher owns activation.
      systemd.user.services.surface-tablet-osk = {
        Unit = {
          Description = "Surface automatic text-input keyboard";
          PartOf = [
            config.wayland.systemd.target
            "surface-tablet-mode.service"
          ];
          ConditionPathExists = "%t/surface-tablet/tablet";
        };
        Service = {
          ExecStart = "${getExe wvkbd} --auto --hidden";
          Environment = [
            "WVKBD_HEIGHT=360"
            "WVKBD_LANDSCAPE_HEIGHT=300"
          ];
          Restart = "on-failure";
          RestartSec = 2;
          NoNewPrivileges = true;
        };
      };
    };
}
