{ pkgs, ... }:
{
  gtk.iconTheme = {
    name = "Yaru";
    package = pkgs.yaru-theme;
  };
}
