{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  imports = singleton inputs.dux-files.nixosModules.dux-files;

  programs.dux-files = {
    enable = true;
    # Keep the Go and Qt runtime paired with upstream's supported nixpkgs.
    # The package wraps dfiles with bubblewrap, ffmpegthumbnailer and
    # poppler-utils on PATH, and includes the Qt PDF preview module.
    package = inputs.dux-files.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
    portal = {
      enable = true;
      preferred = true;
      desktop = "hyprland";
    };
  };

  # Upstream sets `path`, which pins PATH to quickshell and systemd's
  # defaults. Desktop entries use bare Exec names, so launching the default
  # app fails. Drop it to inherit the user manager's session PATH.
  systemd.user.services.dfiles.environment.PATH = mkForce null;

  services = {
    gvfs.enable = true;
    udisks2.enable = true;
  };

  desktop.fileManager.desktopFile = "dev.duxlabs.files.desktop";
}
