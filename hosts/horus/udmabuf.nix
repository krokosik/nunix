{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  boot.kernelModules = singleton "udmabuf";

  # Grant access only to the active local session, before 73-seat-late.rules.
  services.udev.packages = singleton (
    pkgs.writeTextDir "lib/udev/rules.d/70-hookshot-udmabuf.rules" /* udev */ ''
      SUBSYSTEM=="misc", KERNEL=="udmabuf", TAG+="uaccess"
    ''
  );
}
