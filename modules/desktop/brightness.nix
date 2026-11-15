{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  # Grants the active local session access through udev's uaccess rules.
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; singleton ddcutil;
}
