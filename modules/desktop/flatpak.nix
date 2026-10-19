{ inputs, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton inputs.nix-flatpak.nixosModules.nix-flatpak;

  services.flatpak = {
    enable = true;
    packages = [
      # Keep Flathub's --persist=. and isolated home for Parsec's hardcoded state paths.
      "com.parsecgaming.parsec"
      "org.inkscape.Inkscape"
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
