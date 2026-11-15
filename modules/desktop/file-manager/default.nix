{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.types) str;
in
{
  imports = [
    ./dfiles.nix
    # ./nautilus.nix
  ];

  options.desktop.fileManager.desktopFile = mkOption {
    type = str;
    description = "Desktop entry of the selected file manager.";
  };

  config.home-manager.sharedModules = singleton {
    xdg.mimeApps.defaultApplications."inode/directory" = config.desktop.fileManager.desktopFile;
  };
}
