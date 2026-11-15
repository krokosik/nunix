{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
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

  services = {
    gvfs.enable = true;
    udisks2.enable = true;
  };

  desktop.fileManager.desktopFile = "dev.duxlabs.files.desktop";
}
