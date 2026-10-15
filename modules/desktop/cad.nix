{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  services.flatpak = {
    packages = [
      "com.orcaslicer.OrcaSlicer"
      "com.prusa3d.PrusaSlicer"
      "org.freecad.FreeCAD"
      "org.kicad.KiCad"
    ];

    # FreeCAD's default XWayland window does not map in Hyprland.
    overrides.settings."org.freecad.FreeCAD" = {
      Context.sockets = singleton "wayland";
      Environment.QT_QPA_PLATFORM = "wayland";
    };

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
