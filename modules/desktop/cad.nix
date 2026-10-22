{ inputs, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    freecad
    # The repository's `stable` overlay otherwise shadows KiCad's boolean argument.
    (kicad.override { stable = true; })
  ];

  imports = [ inputs.inventor.nixosModules.default ];

  programs.autodesk-inventor = {
    enable = true;
    versions = [ "2027" ];
  };

  services.flatpak = {
    packages = [
      "com.orcaslicer.OrcaSlicer"
      "com.prusa3d.PrusaSlicer"
    ];
  };
}
