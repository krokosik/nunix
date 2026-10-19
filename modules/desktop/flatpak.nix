{ inputs, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton inputs.nix-flatpak.nixosModules.nix-flatpak;

  services.flatpak = {
    enable = true;
    packages = [
      "org.inkscape.Inkscape"
    ];

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
