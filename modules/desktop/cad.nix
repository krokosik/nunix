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
  environment.systemPackages = with pkgs; [
    freecad
    # The repository's `stable` overlay otherwise shadows KiCad's boolean argument.
    (kicad.override { stable = true; })
  ];

  imports = singleton inputs.inventor.nixosModules.default;

  programs.autodesk-inventor = {
    enable = true;
    versions = singleton "2027";
  };

  services.flatpak = {
    packages = [
      "com.orcaslicer.OrcaSlicer"
      "com.prusa3d.PrusaSlicer"
    ];
  };
}
