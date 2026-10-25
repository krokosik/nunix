{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  dconf.settings."org/blueman/general".plugin-list = singleton "AutoConnect";
}
