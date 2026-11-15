{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  environment.systemPackages = with pkgs.unstable; singleton wineWow64Packages.stagingFull;
}
